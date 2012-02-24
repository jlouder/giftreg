package Giftreg::DB::Gift;
use base qw/DBIx::Class::Core/;
use feature qw/switch/;

__PACKAGE__->load_components( qw/PK::Sequence Core/ );
__PACKAGE__->table('gift');

__PACKAGE__->add_columns(
  'gift_id' => {
    data_type      => 'number',
    sequence       => 'gift_id_seq',
  },
  'short_desc' => {
    data_type      => 'varchar',
    size           => 1024,
  },
  'long_desc' => {
    data_type      => 'varchar',
    size           => 4000,
    is_nullable    => 1,
  },
  'location' => {
    data_type      => 'varchar',
    size           => 1024,
    is_nullable    => 1,
  },
  'wanted_by_person_id' => {
    data_type      => 'number',
    is_foreign_key => 1,
  },
  'bought_by_person_id' => {
    data_type      => 'number',
    is_foreign_key => 1,
    is_nullable    => 1,
  },
  'priority_nbr' => {
    data_type      => 'number',
  },
);

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
