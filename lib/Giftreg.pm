package Giftreg;
use Mojo::Base 'Mojolicious';
use Mojolicious::Plugin::Database;

# This method will run once at server start
sub startup {
  my $self = shift;

  # Read configuration file
  my $config = $self->plugin('Config');

  # Set up database connection, available in controllers by calling db().
  $self->plugin('database', {
    dsn      => $config->{db}->{dsn},
    username => $config->{db}->{username},
    password => $config->{db}->{password},
  });

  # Set up authentication plugin
  $self->plugin('authentication' => {
    load_user     => \&Giftreg::Auth::load_user,
    validate_user => \&Giftreg::Auth::validate_user,
  });

  # Routes
  my $r = $self->routes;

  $r->route('/welcome')->to('example#welcome');
  $r->route('/login')->to('auth#login');
  $r->route('/logout')->to('auth#logout');
  $r->route('/user/list')->to('user#list');
}

1;
