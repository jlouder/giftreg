package Giftreg::Password;
use Mojo::Base 'Mojolicious::Controller';
use Giftreg::DB;
use Giftreg::Auth;
use Data::Dumper;

sub mailresetlink {
  my $self = shift;
  my $email_address = $self->param('email_address') || '';

  # Did we get an email address?
  if( $email_address =~ /^\s*$/ ) {
    $self->stash('error_message' => 'Email address is required.');
    $self->render('password/forgot');
  }

  # Make sure the email address is for a known user.
  my $db = Giftreg::DB->connect();
  my $user = $db->resultset('Person')->find({ email_address =>
                                              $email_address });
  if( !defined $user ) {
    $self->stash('error_message' =>
                   'The email address entered does not match a known user.');
    $self->render('password/forgot');
  }

  # Generate a random secret.
  my @charset = ('a' .. 'z', '0' .. '9');
  my $num_chars = scalar @charset;
  my $secret = '';
  foreach ( 1 .. 40 ) {
    $secret .= $charset[ int(rand($num_chars)) ];
  }

  my $pw = $db->resultset('PasswordReset')->create({
    person_id => $user->person_id,
    secret    => $secret,
    expire_dt => time + 60*60*24*4, # 4 days from now
  });

  # Mail the reset link
  if( defined $self->config->{mail}->{how} ) {
    $self->stash(secret => $secret);
    $self->mail(to       => $user->email_address,
                template => 'password/reset',
                format   => 'mail');
  }
}

sub reset {
  my $self = shift;

  my $time_now = time;

  # Make sure the secret code is valid.
  my $secret = $self->param('secret') || '';
  if( $secret eq '' ) {
    $self->render('password/invalid_code');
    return;
  }

  my $db = Giftreg::DB->connect();
  my $pwreset = $db->resultset('PasswordReset')->single({
    secret    => $secret,
    expire_dt => \"> $time_now",
  });

  if( !defined $pwreset ) {
    $self->render('password/invalid_code');
    return;
  }

  $self->stash(email_address => $pwreset->person->email_address);
  $self->stash(secret => $secret);

  # If the password fields are filled out, they must match.
  my $pw1 = $self->param('password');
  my $pw2 = $self->param('confirm_password');
  if( defined $pw1 && defined $pw2 ) {
    if( $pw1 ne $pw2 ) {
      $self->stash(error_message => 'The passwords entered do not match.');
      return;
    }

    # Update the password
    $pwreset->person->password(Giftreg::Auth::hash($pw1));
    $pwreset->person->update;

    $self->render('password/updated');
    return;
  }
}

1;
