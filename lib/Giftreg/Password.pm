package Giftreg::Password;
use Mojo::Base 'Mojolicious::Controller';
use Giftreg::DB;

sub forgot {
  # Just show the form!
}

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
    expire_dt => \'sysdate + 4',
  });

  # TODO: mail the reset link!

}

sub reset {
  my $self = shift;

  # Make sure the secret code is valid.
  my $secret = $self->param('secret');
  my $db = Giftreg::DB->connect();
  my $pwreset = $db->resultset('PasswordReset')->single({
    secret    => $secret,
    expire_dt => \'> sysdate',
  });

  if( !defined $pwreset ) {
    $self->render('password/invalid_code');
  }

  $self->stash(email_address => $pwreset->person->email_address);

  # TODO: check the expire date on the secret
}

1;
