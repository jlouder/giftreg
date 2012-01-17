#!/usr/bin/env perl
use Mojo::Base -strict;

use Test::More tests => 12;
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
  [ 1, 'person1@example.com', 'person1', 1322006400 ],
  [ 2, 'person2@example.com', 'person2', undef ],
]);
$db->populate('Gift', [
  [ qw/ gift_id short_desc long_desc location
        wanted_by_person_id bought_by_person_id priority_nbr / ],
  [ 1, 'Gift 1', 'Longer description of gift 1', 'Anywhere', 1, undef, 3 ],
  [ 2, 'Gift 2', 'Longer description of gift 2', 'Anywhere', 1, 2, 1 ],
]);

$t->get_ok('/user/view/1')->status_is(200)
  ->content_like(qr/last updated on November 23, 2011/i,
                 'last update date format')
  ->content_like(qr/Gift 1/, 'gift 1 listed')
  ->content_like(qr/Gift 2/, 'gift 2 listed')
  ->content_like(qr/Already bought/i, 'gift 2 is bought');

# Log in as the list owner
$t->post_form_ok('/login', {
  username => 'person1@example.com',
  password => 'person1',
});
$t->get_ok('/user/view/1')->status_is(200)
  ->content_like(qr/Unbuy/i, 'unbuy link for owner');
