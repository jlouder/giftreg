package Giftreg::User;
use Mojo::Base 'Mojolicious::Controller';
use Giftreg::DB;
use Mojolicious::Plugin::Authentication;

sub require_login {
  my $self = shift;

  if( $self->user_exists() ) {
    return;
  } else {
    $self->stash( return_to_url => $self->req->url->to_string );
    $self->redirect_to('/login');
  }
}

sub list {
  my $self = shift;

  $self->require_login();

  my $db = Giftreg::DB->connect(sub { return $self->db(); });
#  my @users = $db->resultset('Person')->search(undef, {
#    order_by => 'email_address'
#  });
  my @users = $db->resultset('Gift')->search_related('wanted_by', undef, {
    columns  => [ 'email_address' ],
    order_by => [ 'email_address' ],
    distinct => 1,
  });
  $self->stash(users => \@users);

  $self->render();
}

1;
