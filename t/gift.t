#!/usr/bin/env perl
use Mojo::Base -strict;

use Test::More tests => 88;
use Test::Mojo;
use DBI;

$ENV{MOJO_MODE} = 'testing';

use_ok 'Giftreg';
use_ok 'Giftreg::DB';

my $t = Test::Mojo->new('Giftreg');

# populate the database
my $db = Giftreg::DB->connect();
$db->resultset('Person')->delete_all;
$db->populate('Person', [
  [ qw/ person_id email_address password last_update_dt / ],
  [ 1, 'person1@example.com', 'person1', 1322006400 ],
  [ 2, 'person2@example.com', 'person2', undef ],
  [ 3, 'person3@example.com', 'person3', undef ],
]);
$db->resultset('Gift')->delete_all;
$db->populate('Gift', [
  [ qw/ gift_id short_desc long_desc location
        wanted_by_person_id bought_by_person_id priority_nbr / ],
  [ 1, 'Gift 1', 'Longer description of gift 1', 'Anywhere', 1, undef, 3 ],
  [ 2, 'Gift 2', 'Longer description of gift 2', 'Anywhere', 1, 3, 1 ],
  [ 4, 'Gift 4', 'Longer description of gift 3', 'Anywhere', 3, undef, 1 ],
]);

# Log in and buy a gift
$t->ua->max_redirects(1);
$t->post_ok('/login', form => {
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
  ->content_like(qr/Un-buy/, 'unbuy button present');
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
$t->post_ok('/login', form => {
  username => 'person1@example.com',
  password => 'person1',
});
$t->get_ok('/gift/edit/1')->status_is(200)
  ->element_exists('div#content form', 'edit form present');

# Save a gift ...
# ... already-bought gift
$t->post_ok('/gift/save/2', form => {
  short_desc   => 'A lovely gift',
  long_desc    => 'Something I would really like!',
  location     => 'Anywhere',
  priority_nbr => 1,
})->status_is(200)
  ->content_like(qr/You can only edit gifts that have not been bought/i,
                 'save already-bought gift');

# ... gift belonging to someone else
$t->post_ok('/gift/save/4', form => {
  short_desc   => 'A lovely gift',
  long_desc    => 'Something I would really like!',
  location     => 'Anywhere',
  priority_nbr => 1,
})->status_is(200)
  ->content_like(qr/You can only edit gifts on your list/i,
                 q{save someone else's gift});

# ... invalid gift
$t->post_ok('/gift/save/3', form => {
  short_desc   => 'A lovely gift',
  long_desc    => 'Something I would really like!',
  location     => 'Anywhere',
  priority_nbr => 1,
})->status_is(200)
  ->content_like(qr/The gift you selected is unknown/i,
                 'save invalid gift');

# ... with required fields missing
foreach my $field ( qw( short_desc long_desc location priority_nbr ) ) {
  my %post_data = (
    short_desc   => 'A lovely gift',
    long_desc    => 'Something I would really like!',
    location     => 'Anywhere',
    priority_nbr => 1,
  );
  delete $post_data{$field};

  $t->post_ok('/gift/save/1', form => \%post_data)->status_is(200)
    ->content_like(qr/required fields missing/i, 'missing required field');
}

# ... finally, save a valid edit
my %post_data = (
  short_desc   => 'A lovely gift',
  long_desc    => 'Something I would really like!',
  location     => 'Anywhere',
  priority_nbr => 1,
);
$t->post_ok('/gift/save/1', form => \%post_data)->status_is(200)
  ->content_like(qr/The gift you edited has been saved/i,
                 'save valid gift');

# Make sure each field is updated in the database.
$gift = $db->resultset('Gift')->find(1);
ok(defined $gift, 'found updated gift in db');
foreach my $field ( keys %post_data ) {
  is($gift->$field, $post_data{$field}, "db matches form for field: $field");
}

# Make sure user's last update time was updated.
my $user = $db->resultset('Person')->find(1);
ok(defined $user, 'found user in db');
my $last_update_dt = $user->_last_update_dt;
$t->app->log->debug("last_update_dt: $last_update_dt");
ok($last_update_dt > time - 60, 'user last_update_dt within last minute');

sleep 1;  # guarantee next save modifies last_update_dt

# Save a new gift
%post_data = (
  short_desc   => 'A new gift',
  long_desc    => 'Long description of a new gift',
  location     => 'Anywhere',
  priority_nbr => 1,
);
$t->post_ok('/gift/save/new', form => \%post_data)->status_is(200)
  ->content_like(qr/The gift you edited has been saved/i,
                 'save valid gift');

# Find the new gift in the database and make sure it matches what was saved.
my @gifts = $db->resultset('Gift')->search({short_desc => 'A new gift'});
$gift = $gifts[0];
ok(defined $gift, 'found new gift in db');
foreach my $field ( keys %post_data ) {
  is($gift->$field, $post_data{$field}, "db matches form for field: $field");
}

# Make sure user's last update time was updated (again).
$user = $db->resultset('Person')->find(1);
ok(defined $user, 'found user in db');
ok($user->_last_update_dt > $last_update_dt,
   'user last_update_dt updated');

# Delete the gift just added
my $gift_id_to_delete = $gift->gift_id;
$t->get_ok("/gift/delete/$gift_id_to_delete")->status_is(200)
  ->content_like(qr/The gift you selected has been deleted/i,
                 'delete newly-added gift');

# Make sure the gift no longer exists in the database.
@gifts = $db->resultset('Gift')->search({short_desc => 'A new gift'});
ok(!@gifts, 'gift removed from db');

# Try to delete a gift that belongs to someone else.
$t->get_ok('/gift/delete/4')->status_is(200)
  ->content_like(qr/You can only delete gifts on your list/i,
                 q{delete someone else's gift});

# Try to delete an invalid gift.
$t->get_ok('/gift/delete/5')->status_is(200)
  ->content_like(qr/The gift you selected is unknown/i,
                 'delete invalid gift');
