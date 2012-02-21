package Giftreg;
use Mojo::Base 'Mojolicious';
use Mojolicious::Plugin::Database;
use Mojolicious::Plugin::Mail;
use Giftreg::Auth;
use Giftreg::Gift;
use Giftreg::DB;

# This method will run once at server start
sub startup {
  my $self = shift;

  $self->secret('iWCithIiPkv660gNbzzK0HZgf');

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
  $self->helper('require_login' => \&Giftreg::Auth::require_login);

  # Set up mail plugin
  $self->plugin(mail => $config->{mail});

  # Add presentation helpers
  Giftreg::Gift::add_helpers($self);

  # Seed the random number generator. Perl does this automatically at the
  # first call to rand(), but when we're running under morbo, we keep
  # getting killed and respawned, inheriting the parent process' seed each
  # time.
  srand(time ^ ($$ + ($$ << 15)));

  # Routes
  my $r = $self->routes;

  $r->route('/login')->to('auth#login');
  $r->route('/logout')->to('auth#do_logout');

  $r->route('/user/list')->to('user#list');
  $r->route('/user/view/:uid')->to('user#view');
  $r->route('/user/edit')->to('user#edit');

  $r->route('/gift/buy/:gift_id')->to('gift#buy');
  $r->route('/gift/unbuy/:gift_id')->to('gift#unbuy');
  $r->route('/gift/edit/:gift_id')->to('gift#edit');
  $r->route('/gift/save/:gift_id')->to('gift#save');
  $r->route('/gift/delete/:gift_id')->to('gift#delete');

  $r->route('/password/forgot')->to('password#forgot');
  $r->route('/password/mailresetlink')->to('password#mailresetlink');
  $r->route('/password/reset/:secret')->to('password#reset');
  $r->route('/password/reset')->to('password#reset');

  $r->route('/')->to('user#list');
}

1;
