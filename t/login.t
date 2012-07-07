#!/usr/bin/env perl
use Mojo::Base -strict;

use Test::More tests => 29;
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
  username => 'person2@example.com',
  password => 'badpassword',
})->status_is(200)->content_like(qr/Login failed/, 'failed login error');

# Create a new user ...
# ... with an email address that is already in use
$t->post_form_ok('/login', {
  newuser_username         => 'person1@example.com',
  newuser_password         => 'newpassword',
  newuser_password_confirm => 'newpassword',
})->status_is(200)->content_like(qr/already in use/i,
                                 'register duplicate user');

# ... without a password
$t->post_form_ok('/login', {
  newuser_username         => 'person3@example.com',
})->status_is(200)->content_like(qr/enter a password/i,
                                 'register user without password');

# ... with passwords that don't match
$t->post_form_ok('/login', {
  newuser_username         => 'person3@example.com',
  newuser_password         => 'newpassword',
  newuser_password_confirm => 'differentpassword',
})->status_is(200)->content_like(qr/do not match/i,
                                 'new user passwords do not match');

# ... correctly
$t->post_form_ok('/login', {
  newuser_username         => 'person3@example.com',
  newuser_password         => 'newpassword',
  newuser_password_confirm => 'newpassword',
})->status_is(200)->content_like(qr/account has been created/i,
                                 'register new user')
  ->content_like(qr/Welcome, person3\@example\.com/, 'new user is logged in');

# Confirm the new user's database password is hashed.
my @users = $db->resultset('Person')->search({
  email_address => 'person3@example.com',
});
my $user = $users[0];
ok(defined $user, 'found new user in database');
like($user->password, qr/\$1\$\S+\$\S+/, 'db password is hashed');
