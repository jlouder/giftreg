#!/usr/bin/env perl
use Mojo::Base -strict;

use Test::More tests => 14;
use Test::Mojo;
use DBI;

$ENV{MOJO_MODE} = 'testing';

use_ok 'Giftreg';
use_ok 'Giftreg::DB';

my $t = Test::Mojo->new('Giftreg');

# populate the database
my $db = Giftreg::DB->connect();
$db->deploy();
$db->populate('Person', [
  [ qw/ person_id email_address password last_update_dt / ],
  [ 1, 'person1@example.com', 'person1', undef ],
  [ 2, 'person2@example.com', 'person2', undef ],
]);
$db->populate('Gift', [
  [ qw/ gift_id short_desc long_desc location
        wanted_by_person_id bought_by_person_id priority_nbr / ],
  [ 1, 'Gift 1', 'Longer description of gift 1', 'Anywhere', 1, undef, 3 ],
  [ 2, 'Gift 2', 'Longer description of gift 2', 'Anywhere', 1, undef, 1 ],
]);

# Get the login form
$t->get_ok('/login')->status_is(200);

# Submit the form with a valid username/password
$t->max_redirects(1);
$t->post_form_ok('/login', {
  username => 'person1@example.com',
  password => 'person1',
})->status_is(200)  # follows redirect
  ->content_like(qr/Welcome, person1\@example\.com/, 'username in header');

# Now, log out
$t->get_ok('/logout')->status_is(200)
  ->content_like(qr/logged out/i, 'logged out')
  ->content_like(qr/Login/, 'login link present');

# Submit the form with an invalid username/password
$t->post_form_ok('/login', {
  username => 'person1@example.com',
  password => 'badpassword',
})->status_is(200)->content_like(qr/Login failed/, 'failed login error');
