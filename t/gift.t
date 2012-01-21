#!/usr/bin/env perl
use Mojo::Base -strict;

use Test::More tests => 37;
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
  [ 3, 'person3@example.com', 'person3', undef ],
]);
$db->populate('Gift', [
  [ qw/ gift_id short_desc long_desc location
        wanted_by_person_id bought_by_person_id priority_nbr / ],
  [ 1, 'Gift 1', 'Longer description of gift 1', 'Anywhere', 1, undef, 3 ],
  [ 2, 'Gift 2', 'Longer description of gift 2', 'Anywhere', 1, 3, 1 ],
]);

# Log in and buy a gift
$t->max_redirects(1);
$t->post_form_ok('/login', {
  username => 'person2@example.com',
  password => 'person2',
});
$t->get_ok('/gift/buy/3')->status_is(200)
  ->content_like(qr/The gift you selected is unknown/i, 'buy invalid gift');
$t->get_ok('/gift/buy/2')->status_is(200)
  ->content_like(qr/The gift you selected is already bought/i,
                 'buy already-bought gift');
$t->get_ok('/gift/buy/1')->status_is(200)
  ->content_like(qr/The gift you selected has been bought/i,
                 'buy available gift');
my $gift = $db->resultset('Gift')->find(1);
ok($gift->is_bought, 'gift 1 is bought in db');

# Unbuy the gift just bought
$t->get_ok('/user/view/1')->status_is(200)
  ->content_like(qr/Unbuy/, 'unbuy button present');
$t->get_ok('/gift/unbuy/3')->status_is(200)
  ->content_like(qr/The gift you selected is unknown/i, 'unbuy invalid gift');
$t->get_ok('/gift/unbuy/2')->status_is(200)
  ->content_like(qr/You can only unbuy gifts you bought/i,
                 q{unbuy someone else's gift});
$gift = $db->resultset('Gift')->find(2);
ok($gift->is_bought, 'gift 2 is still bought in db');
$t->get_ok('/gift/unbuy/1')->status_is(200)
  ->content_like(qr/The gift you selected has been unbought/i,
                 'unbuy eligible gift');
$gift = $db->resultset('Gift')->find(1);
ok(!$gift->is_bought, 'gift 1 is not bought in db');

# Edit a gift
$t->get_ok('/gift/edit/3')->status_is(200)
  ->content_like(qr/The gift you selected is unknown/i, 'edit invalid gift');
$t->get_ok('/gift/edit/2')->status_is(200)
  ->content_like(qr/You can only edit gifts on your list/i,
                 q{edit someone else's gift});
$t->post_form_ok('/login', {
  username => 'person1@example.com',
  password => 'person1',
});
$t->get_ok('/gift/edit/1')->status_is(200)
  ->element_exists('div#content form', 'edit form present');
