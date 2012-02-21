package Giftreg::Gift;
use Mojo::Base 'Mojolicious::Controller';
use Giftreg::DB;

sub add_helpers {
  my $self = shift;
  # Prints the un-buy button and link, or nothing, depending on who's logged in.
  $self->app->helper(unbuy_button => sub {
    my ($self, $gift) = @_;
  
    # Anonymous users never see the button.
    return '' unless $self->user_exists;
  
    # Don't show the button if the gift is not bought.
    return '' unless $gift->is_bought;
  
    # Show the button for gifts bought by the currently logged-in user,
    # or for everything if this user owns the list.
    if( $self->user->person_id == $gift->wanted_by_person_id ||
        $self->user->person_id == $gift->bought_by_person_id ) {
      my $link_url = $self->url_for('/gift/unbuy/' . $gift->gift_id);
      return qq{<a href="$link_url" class="button">Unbuy</a>};
    }
  
    return '';
  });
  
  # Prints the edit button.
  $self->app->helper(edit_button => sub {
    my ($self, $gift) = @_;
  
    return '' unless $self->user_exists;
  
    if( $self->user->person_id == $gift->wanted_by_person_id ) {
      my $link_url = $self->url_for('/gift/edit/' . $gift->gift_id);
      return qq{<a href="$link_url" class="button">Edit</a>};
    }
  
    return '';
  });
  
  # Prints the delete button.
  $self->app->helper(delete_button => sub {
    my ($self, $gift) = @_;
  
    return '' unless $self->user_exists;
  
    if( $self->user->person_id == $gift->wanted_by_person_id ) {
      my $link_url = $self->url_for('/gift/delete/' . $gift->gift_id);
      return qq{<a href="$link_url" class="button">Delete</a>};
    }
  
    return '';
  });

  # Prints the buy button.
  $self->app->helper(buy_button => sub {
    my ($self, $gift) = @_;
  
    return '' if $gift->is_bought;
  
    my $link_url = $self->url_for('/gift/buy/' . $gift->gift_id);
    my $link_text=qq{<a href="$link_url" class="button">Buy</a>};
  
    if( !$self->user_exists ) {
      return $link_text;
    }
  
    if( $self->user->person_id == $gift->wanted_by_person_id ) {
      return '';
    }
  
    return $link_text;
  });
  
  # Prints the bought message, for bought gifts the user can't unbuy.
  $self->app->helper(bought_message => sub {
    my ($self, $gift) = @_;
  
    if( $gift->is_bought && $self->unbuy_button($gift) eq '' ) {
      return 'Already bought';
    }
  
    return '';
  });
}

sub unbuy {
  my $self = shift;

  $self->require_login() or return;;

  # when we're done, we'll redirect to the previous URL
  my $prev_url = $self->req->headers->referrer || '/';

  my $gift_id = $self->param('gift_id');
  my $db = Giftreg::DB->connect();
  my $gift = $db->resultset('Gift')->find($gift_id);

  if( !defined $gift ) {
    $self->flash('error_message' => 'The gift you selected is unknown.');
    $self->redirect_to($prev_url);
    return;
  }

  $prev_url = '/user/view/' . $gift->wanted_by_person_id;

  if( $gift->wanted_by_person_id != $self->user->person_id &&
      $gift->bought_by_person_id != $self->user->person_id ) {
    $self->flash('error_message' => 'You can only unbuy gifts you bought ' .
                 'or gifts on your list.');
    $self->redirect_to($prev_url);
    return;
  }

  $gift->bought_by_person_id(undef);
  $gift->update;
  $self->flash('message' => 'The gift you selected has been unbought.');
  $self->redirect_to($prev_url);
}

sub buy {
  my $self = shift;

  $self->require_login() or return;

  # After this action, we redirect to the previous URL.
  my $prev_url = $self->req->headers->referrer || '/';

  my $gift_id = $self->param('gift_id');
  my $db = Giftreg::DB->connect();
  my $gift = $db->resultset('Gift')->find($gift_id);

  if( !defined $gift ) {
    $self->flash('error_message' => 'The gift you selected is unknown.');
    $self->redirect_to($prev_url);
    return;
  }

  $prev_url = '/user/view/' . $gift->wanted_by_person_id;

  if( $gift->is_bought ) {
    $self->flash('error_message' => 'The gift you selected is already bought.');
    $self->redirect_to($prev_url);
    return;
  }

  $gift->bought_by_person_id($self->user->person_id);
  $gift->update;
  $self->flash('message' => 'The gift you selected has been bought.');
  $self->redirect_to($prev_url);
}

sub edit {
  my $self = shift;

  $self->require_login() or return;

  my $next_url = $self->req->headers->referrer || '/';

  my $gift_id = $self->param('gift_id');
  my $db = Giftreg::DB->connect();
  my $gift = $db->resultset('Gift')->find($gift_id);

  if( !defined $gift ) {
    $self->flash('error_message' => 'The gift you selected is unknown.');
    $self->redirect_to($next_url);
    return;
  }

  $next_url = '/user/view/' . $gift->wanted_by_person_id;

  if( $gift->wanted_by_person_id != $self->user->person_id ) {
    $self->flash('error_message' => 'You can only edit gifts on your list.');
    $self->redirect_to($next_url);
    return;
  }

  $self->stash('gift' => $gift);
}

sub save {
  my $self = shift;

  $self->require_login() or return;

  my $next_url = $self->req->headers->referrer || '/';

  my $gift_id = $self->param('gift_id');
  my $db = Giftreg::DB->connect();
  my $gift;

  if( $gift_id ne 'new' ) {
    $gift = $db->resultset('Gift')->find($gift_id);
  
    if( !defined $gift ) {
      $self->flash('error_message' => 'The gift you selected is unknown.');
      $self->redirect_to($next_url);
      return;
    }
  
    if( $gift->wanted_by_person_id != $self->user->person_id ) {
      $self->flash('error_message' => 'You can only edit gifts on your list.');
      $self->redirect_to($next_url);
      return;
    }
  
    if( defined $gift->bought_by_person_id ) {
      $self->flash('error_message' => 'You can only edit gifts ' .
                                      'that have not been bought.');
      $self->redirect_to($next_url);
      return;
    }
  }

  # Check for required fields
  foreach my $field ( qw( short_desc long_desc location priority_nbr ) ) {
    if( !defined $self->param($field) ) {
      $self->flash('error_message' => 'One or more required fields missing');
      $self->redirect_to("/gift/edit/$gift_id");
      return;
    }
  }

  # Save the updates
  if( $gift_id eq 'new' ) {
    $gift = $db->resultset('Gift')->create({
      short_desc          => $self->param('short_desc'),
      long_desc           => $self->param('long_desc'),
      location            => $self->param('location'),
      priority_nbr        => $self->param('priority_nbr'),
      wanted_by_person_id => $self->user->person_id,
    });
  } else {
    foreach my $field ( qw( short_desc long_desc location priority_nbr ) ) {
      $gift->$field($self->param($field));
    }
    $gift->update;
  }

  # Update the user's last_update_dt time.
  $self->user->last_update_dt(time);
  $self->user->update;

  $self->flash('message' => 'The gift you edited has been saved.');
  $self->redirect_to('/user/view/' . $self->user->person_id);
}

1;
