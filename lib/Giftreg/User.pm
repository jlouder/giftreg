package Giftreg::User;
use Mojo::Base 'Mojolicious::Controller';
use Giftreg::DB;
use Giftreg::Auth;
use Mojolicious::Plugin::Authentication;

sub list {
  my $self = shift;

  my $db = Giftreg::DB->connect();
  my @users = $db->resultset('Gift')->search_related('wanted_by', undef, {
    order_by => [ 'email_address' ],
    distinct => 1,
  });
  $self->stash(users => \@users);

  $self->render();
}

sub view {
  my $self = shift;
  my $uid = $self->param('uid');

  my $db = Giftreg::DB->connect();
  my @gifts = $db->resultset('Gift')->search(
    { wanted_by_person_id => $uid },
    { order_by  => [ 'bought_by_person_id DESC', 'priority_nbr ASC' ] },
  );
  my $user = $db->resultset('Person')->find($uid);
  $self->stash(gifts => \@gifts);
  $self->stash(user => $user);
}

# edit is the same as view for the current user, but forces a login
sub edit {
  my $self = shift;

  $self->require_login() or return;;

  $self->redirect_to('/user/view/' . $self->user->person_id);
}

1;
