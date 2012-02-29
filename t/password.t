#!/usr/bin/env perl
use Mojo::Base -strict;

use Test::More tests => 24;
use Test::Mojo;
use DBI;
use IO::File;

$ENV{MOJO_MODE} = 'testing';

use_ok 'Giftreg';
use_ok 'Giftreg::DB';

my $t = Test::Mojo->new('Giftreg');

# populate the database
my $db = Giftreg::DB->connect();
$db->resultset('Person')->delete_all;
$db->populate('Person', [
  [ qw/ person_id email_address password last_update_dt / ],
  [ 1, 'person1@example.com', 'person1', undef ],
  [ 2, 'person2@example.com', 'person2', undef ],
]);
$db->resultset('Gift')->delete_all;
$db->populate('Gift', [
  [ qw/ gift_id short_desc long_desc location
        wanted_by_person_id bought_by_person_id priority_nbr / ],
  [ 1, 'Gift 1', 'Longer description of gift 1', 'Anywhere', 1, undef, 3 ],
  [ 2, 'Gift 2', 'Longer description of gift 2', 'Anywhere', 1, undef, 1 ],
]);
$db->resultset('PasswordReset')->delete_all;

# Get the password reset form
$t->get_ok('/password/forgot')->status_is(200);

# Submit the form
$t->post_form_ok('/password/mailresetlink', {
  email_address => 'person1@example.com',
})->status_is(200);

# This should have inserted a row into the password_reset table. Get the
# secret from that table (previously empty).
my $pwreset = $db->resultset('PasswordReset')->single();
ok(defined $pwreset, 'found password reset secret');
ok($pwreset->person_id == 1, 'secret belongs to correct user');

# Get the reset page with an invalid code
$t->get_ok('/password/reset/s0me1nval1dc0de')->status_is(200)
  ->content_like(qr/Invalid reset code/);

# Get the reset page with no code
$t->get_ok('/password/reset')->status_is(200)
  ->content_like(qr/Invalid reset code/);

# Get the reset page with the real code
my $secret = $pwreset->secret;
$t->get_ok("/password/reset/$secret")->status_is(200)
  ->content_like(qr/person1\@example\.com/);

# Submit the reset form with different passwords
$t->post_form_ok('/password/reset', {
  secret           => $secret,
  password         => 'one',
  confirm_password => 'two',
})->status_is(200)->content_like(qr/do not match/i);

# Submit the reset form properly
$t->post_form_ok('/password/reset', {
  secret           => $secret,
  password         => 'newpassword',
  confirm_password => 'newpassword',
})->status_is(200)->content_like(qr/has been updated/i);

# Confirm the database password is hashed.
my $user = $db->resultset('Person')->find(1);
like($user->password, qr/\$1\$\S+\$\S+/, 'db password is hashed');
