package Giftreg;
use Mojo::Base 'Mojolicious';
use Mojolicious::Plugin::Database;
use Mojolicious::Plugin::Mail;
use Giftreg::Auth;
use Giftreg::DB;

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

  # Overload the connect() method of our DBIx::Class schema, so we don't have
  # to specify all these arguments each time connect is called.
  Giftreg::DB->connection(sub { return $self->db(); },
                          $config->{db}->{options});

  # Set up authentication plugin
  $self->plugin('authentication' => {
    load_user     => \&Giftreg::Auth::load_user,
    validate_user => \&Giftreg::Auth::validate_user,
  });

  # Set up mail plugin
  $self->plugin(mail => $config->{mail});

  # Routes
  my $r = $self->routes;

  $r->route('/welcome')->to('example#welcome');
  $r->route('/login')->to('auth#login');
  $r->route('/logout')->to('auth#logout');
  $r->route('/user/list')->to('user#list');
  $r->route('/user/view/:uid')->to('user#view');

  $r->route('/password/forgot')->to('password#forgot');
  $r->route('/password/mailresetlink')->to('password#mailresetlink');
  $r->route('/password/reset/:secret')->to('password#reset');
}

1;
