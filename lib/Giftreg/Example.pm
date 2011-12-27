package Giftreg::Example;
use Mojo::Base 'Mojolicious::Controller';
use Giftreg::DB;

# This action will render a template
sub welcome {
  my $self = shift;

  # Render template "example/welcome.html.ep" with message
  $self->render(
    message => 'Welcome to the Mojolicious real-time web framework!');
}

1;
