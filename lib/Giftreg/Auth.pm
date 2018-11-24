package Giftreg::Auth;
use Mojo::Base 'Mojolicious::Controller';
use Giftreg::DB;
use Digest::SHA qw(sha1_hex);

# SUBROUTINE:  load_user($app, $uid)
# DESCRIPTION: Looks up the user $uid from the database. This is intended
#              to be used by the Authentication plugin.
# RETURNS:     A Giftreg::DB::Person object, or undef if not found.
sub load_user {
  my ($app, $uid) = @_;

  my $db = Giftreg::DB->connect();
  return $db->resultset('Person')->find($uid);
}

# SUBROUTINE:  hash($cleartext)
# DECRIPTION:  Hashes a cleartext password.
# RETURNS:     The hashed value, of the form "$1$<salt>$<hash>".
sub hash {
  my ($cleartext) = @_;

  # Generate an 8-character random salt.
  my @charset = ('a' .. 'z', '0' .. '9');
  my $num_chars = scalar @charset;
  my $salt = '';
  foreach( 1 .. 8 ) {
    $salt .= $charset[ int(rand($num_chars)) ];
  }

  # Generate hash from the salt
  my $hash = sha1_hex($salt . $cleartext);
  return "\$1\$$salt\$$hash";
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
    my $cleartext_password = $user->password;
    $user->password(hash($cleartext_password));
    $user->update();

    return undef unless $password eq $cleartext_password;
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

  if( $self->is_user_authenticated() ) {
    return 1;
  } else {
    $self->flash( return_to_url => $self->req->url->to_string );
    $self->redirect_to('/login');
    return 0;
  }
}

sub check {
  my $self = shift;

  if( $self->is_user_authenticated() ) {
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

  my $username = $self->param('username') || '';
  my $password = $self->param('password') || '';
  my $newuser_username = $self->param('newuser_username') || '';
  my $newuser_password = $self->param('newuser_password') || '';
  my $newuser_password_confirm = $self->param('newuser_password_confirm') || '';
  my $return_to_url = $self->param('return_to_url') || '/';

  # No username in the existing user or new user fields? Print the login form.
  if( $username eq '' && $newuser_username eq '' ) {
    return;
  }

  if( $username ne '' ) {
    # Existing user login; check the password that was entered.
    if( $self->authenticate($username, $password) ) {
      $self->redirect_to($return_to_url);
      return;
    } else {
      # Redisplay the login form with an error message.
      $self->stash(
        error_message => 'Login failed'
      );
      return;
    }
  }

  # Register a new user.

  # Make sure the email address isn't already being used.
  my $db = Giftreg::DB->connect();
  my @users = $db->resultset('Person')->search({
    email_address => $newuser_username,
  });
  if( @users ) {
    $self->stash(
      error_message => 'The email address you entered is already in use.'
    );
    return;
  }

  # Make sure the both password fields are present and match.
  if( $newuser_password eq '' || $newuser_password_confirm eq '' ) {
    $self->stash(
      error_message => 'You must enter a password in both fields.'
    );
    return;
  } 
  if( $newuser_password ne $newuser_password_confirm ) {
    $self->stash(
      error_message => 'The passwords you entered do not match.'
    );
    return;
  }

  # Add the new user to the database.
  $db->resultset('Person')->create({
    email_address => $newuser_username,
    password      => hash($newuser_password),
  });
  $self->flash(
    message => 'Your account has been created.'
  );
  # Log the new user in.
  $self->authenticate($newuser_username, $newuser_password);
  $self->redirect_to($return_to_url);
}

# Named so as not to conflict with the 'logout' helper.
sub do_logout {
  my $self = shift;

  $self->logout();
  $self->flash(message => 'You have been logged out.');
  $self->redirect_to('/');
}

1;
