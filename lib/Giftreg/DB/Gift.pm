package Giftreg::DB::Gift;
use base qw/DBIx::Class::Core/;
use feature qw/switch/;

__PACKAGE__->table('giftreg_schema.gift');

__PACKAGE__->add_columns(qw/ gift_id short_desc long_desc location
                             wanted_by_person_id bought_by_person_id
                             priority_nbr /);
__PACKAGE__->set_primary_key('gift_id');

__PACKAGE__->belongs_to('wanted_by', => 'Giftreg::DB::Person',
                        'wanted_by_person_id');

__PACKAGE__->belongs_to('bought_by', => 'Giftreg::DB::Person',
                        'bought_by_person_id');

sub priority_desc {
  my $self = shift;

  given($self->priority_nbr) {
    when (1) { return "Highest"; }
    when (2) { return "High";    }
    when (3) { return "Medium";  }
    when (4) { return "Low";     }
    when (5) { return "Lowest";  }
    default  { return "Unknown"; }
  }
}

sub is_bought {
  my $self = shift;

  return defined $self->bought_by_person_id;
}

1;
