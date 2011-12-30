package Giftreg::Auth;
use Mojo::Base 'Mojolicious::Controller';
use Giftreg::DB;
use Digest::SHA1 qw(sha1_hex);

# SUBROUTINE:  load_user($app, $uid)
# DESCRIPTION: Looks up the user $uid from the database. This is intended
#              to be used by the Authentication plugin.
# RETURNS:     A Giftreg::DB::Person object, or undef if not found.
sub load_user {
  my ($app, $uid) = @_;

  my $db = Giftreg::DB->connect();
  return $db->resultset('Person')->find($uid);
}

# SUBROUTINE:  validate_user($app, $username, $password, $extradata)
# DESCRIPTION: Checks a user's password. This is intended to be used by
#              the Authentication plugin.
# RETURNS:     The uid of the user if authentication is successful, undef
#              for all errors.
sub validate_user {
  my ($app, $username, $password, $extradata) = @_;

  # Look up this user by name.
  my $db = Giftreg::DB->connect();
  my @users = $db->resultset('Person')->search({
    email_address => $username
  });
  return undef unless @users;

  # The password might be cleartext or hashed ("$1$<salt>$<hash>").
  # If it's cleartext, after comparing the password update it to be hashed.
  my $user = $users[0];
  if( $user->password() =~ /^\$1\$(\w+)\$(\w+)/ ) {
    # Hashed password; just do the comparison.
    my ($salt, $correct_hash) = ($1, $2);
    my $computed_hash = sha1_hex($salt . $password);
    return undef unless $computed_hash eq $correct_hash;
  } else {
    # Cleartext password; update it to be hashed.

    # Generate an 8-character random salt.
    my @charset = ('a' .. 'z', '0' .. '9');
    my $num_chars = scalar @charset;
    my $salt = '';
    while( length $salt < 8 ) {
      $salt .= $charset[ int(rand($num_chars)) ];
    }

    # Generate hash from the salt, then update it in the database.
    my $cleartext_password = $user->password();
    my $hash = sha1_hex($salt . $cleartext_password);
    $user->password("\$1\$$salt\$$hash");
    $user->update();

    return undef unless $password = $cleartext_password;
  }

  # User has successfully authenticated.
  return $user->person_id();
}

# SUBROUTINE:  require_login($controller)
# DESCRIPTION: Controller methods call this function if their action requires
#              a login. This redirects to the login page if the user is not
#              already logged in.
sub require_login {
  my $self = shift;

  if( $self->user_exists() ) {
    return;
  } else {
    $self->stash( return_to_url => $self->req->url->to_string );
    $self->redirect_to('/login');
  }
}

sub check {
  my $self = shift;

  if( $self->user_exists() ) {
    $self->app->log->debug('auth check: user is logged in');
    return 1;
  } else {
    $self->redirect_to('/login');
    $self->app->log->debug('auth check: user is not logged in');
    return 0;
  }
}

sub login {
  my $self = shift;

  my $username = $self->param('username');
  my $password = $self->param('password');

  # No username/password? Print the login form.
  if( !defined $username || !defined $password ) {
    return;
  }

  # Check the password that was entered.
  if( $self->authenticate($username, $password) ) {
    # FIXME: This should redirect to the page the user was trying to load
    # originally when authentication was required.
    $self->redirect_to('/user/list');
    return;
  } else {
    # Redisplay the login form with an error message.
    $self->stash(
      error_message => 'Login failed'
    );
    return;
  }
}

sub logout {
  my $self = shift;

  $self->app->logout();
  $self->redirect_to('/login', error_message => 'You have been logged out.');
}

1;
