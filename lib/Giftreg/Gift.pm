package Giftreg::Gift;
use Mojo::Base 'Mojolicious::Controller';
use Giftreg::DB;

sub add_helpers {
  my $self = shift;

  $self->app->helper(can_unbuy => sub {
    my ($self, $gift) = @_;

    # Anonymous users can't unbuy
    return 0 unless $self->is_user_authenticated;

    # Can't unbuy if the gift isn't already bought
    return 0 unless $gift->is_bought;

    # Show the button for gifts bought by the currently logged-in user,
    # or for everything if this user owns the list.
    if( $self->current_user->person_id == $gift->wanted_by_person_id ||
        $self->current_user->person_id == $gift->bought_by_person_id ) {
      return 1;
    }

    return 0;
  });
  
  $self->app->helper(can_edit => sub {
    my ($self, $gift) = @_;

    # Anonymous users can't edit.
    return 0 unless $self->is_user_authenticated;

    # Don't allow editing if the gift is bought (users should unbuy first).
    return 0 if $gift->is_bought;

    if( $self->current_user->person_id == $gift->wanted_by_person_id ) {
      return 1;
    }

    return 0;
  });
  
  $self->app->helper(can_delete => sub {
    my ($self, $gift) = @_;
  
    return 0 unless $self->is_user_authenticated;
  
    if( $self->current_user->person_id == $gift->wanted_by_person_id ) {
      return 1;
    }
  
    return 0;
  });

  $self->app->helper(can_buy => sub {
    my ($self, $gift) = @_;
  
    return 0 if $gift->is_bought;
  
    if( !$self->is_user_authenticated ) {
      return 1;
    }
  
    if( $self->current_user->person_id == $gift->wanted_by_person_id ) {
      return 0;
    }
  
    return 1;
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

  if( $gift->wanted_by_person_id != $self->current_user->person_id &&
      $gift->bought_by_person_id != $self->current_user->person_id ) {
    $self->flash('error_message' => 'You can only unbuy gifts you bought ' .
                 'or gifts on your list.');
    $self->redirect_to($prev_url);
    return;
  }

  $gift->bought_by_person_id(undef);
  $gift->update;
  $self->flash('message' => 'The gift you selected has been unbought.');

  # Update the user's last_update_dt time.
  $self->current_user->last_update_dt(time);
  $self->current_user->update;

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

  $gift->bought_by_person_id($self->current_user->person_id);
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

  if( $gift->wanted_by_person_id != $self->current_user->person_id ) {
    $self->flash('error_message' => 'You can only edit gifts on your list.');
    $self->redirect_to($next_url);
    return;
  }

  $self->stash('gift' => $gift);
}

sub delete {
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

  if( $gift->wanted_by_person_id != $self->current_user->person_id ) {
    $self->flash('error_message' => 'You can only delete gifts on your list.');
    $self->redirect_to('/user/view/' . $gift->wanted_by_person_id);
    return;
  }

  $gift->delete;
  $self->flash('message' => 'The gift you selected has been deleted.');

  # Update the user's last_update_dt time.
  $self->current_user->last_update_dt(time);
  $self->current_user->update;

  $self->redirect_to('/user/view/' . $self->current_user->person_id);
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
  
    if( $gift->wanted_by_person_id != $self->current_user->person_id ) {
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
      wanted_by_person_id => $self->current_user->person_id,
    });
  } else {
    foreach my $field ( qw( short_desc long_desc location priority_nbr ) ) {
      $gift->$field($self->param($field));
    }
    $gift->update;
  }

  # Update the user's last_update_dt time.
  $self->current_user->last_update_dt(time);
  $self->current_user->update;

  $self->flash('message' => 'The gift you edited has been saved.');
  $self->redirect_to('/user/view/' . $self->current_user->person_id);
}

sub add {
  my $self = shift;

  $self->require_login() or return;

  # Create an "empty" gift object for the edit template.
  my $gift = Giftreg::DB::Gift->new;
  $gift->gift_id('new');
  $gift->priority_nbr(1);

  $self->stash('gift' => $gift);

  $self->render('gift/edit');
}

1;
