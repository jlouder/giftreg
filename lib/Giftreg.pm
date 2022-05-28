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

  $self->secrets(['iWCithIiPkv660gNbzzK0HZgf']);

  # Read configuration file
  my $config = $self->plugin('Config');

  # Set up database connection, available in controllers by calling db().
  $self->plugin('database', {
    dsn      => $config->{db}->{dsn},
    username => $config->{db}->{username},
    password => $config->{db}->{password},
    options  => $config->{db}->{options},
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

  # If 'base_path' is defined in the configuration, we're behind a reverse
  # proxy. Set the base path to this value so that we compute relative
  # URLs correctly.
  if( defined $config->{base_path} ) {
    $self->hook('before_dispatch' => sub {
      my $self = shift;
        
      if ($self->req->headers->header('X-Forwarded-Host')) {
        $self->req->url->base->path->parse($config->{base_path});
      }
    });
  }

  # Routes
  my $r = $self->routes;

  $r->get('/login')->to('auth#login');
  $r->post('/login')->to('auth#login');
  $r->get('/logout')->to('auth#do_logout');

  $r->get('/user/list')->to('user#list');
  $r->get('/user/view/:uid')->to('user#view');
  $r->get('/user/edit')->to('user#edit');

  $r->get('/gift/buy/:gift_id')->to('gift#buy');
  $r->get('/gift/unbuy/:gift_id')->to('gift#unbuy');
  $r->get('/gift/edit/:gift_id')->to('gift#edit');
  $r->post('/gift/save/:gift_id')->to('gift#save');
  $r->get('/gift/delete/:gift_id')->to('gift#delete');
  $r->get('/gift/add')->to('gift#add');

  $r->get('/password/forgot')->to('password#forgot');
  $r->post('/password/mailresetlink')->to('password#mailresetlink');
  $r->get('/password/reset/:secret')->to('password#reset');
  $r->get('/password/reset')->to('password#reset');
  $r->post('/password/reset')->to('password#reset');

  $r->get('/')->to('user#list');
}

1;
