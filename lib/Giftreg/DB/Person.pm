package Giftreg::DB::Person;
use base qw/DBIx::Class::Core/;
use POSIX qw/strftime/;

__PACKAGE__->table('person');

__PACKAGE__->add_columns(
  'person_id' => {
    data_type   => 'number',
    sequence    => 'person_id_seq',
  },
  'email_address' => {
    data_type   => 'varchar',
    size        => 100,
  },
  'password' => {
    data_type   => 'varchar',
    size        => 100,
  },
  'last_update_dt' => {
    data_type   => 'number',
    is_nullable => 1,
  },
);

__PACKAGE__->set_primary_key('person_id');
__PACKAGE__->add_unique_constraint([ qw/ email_address / ]);

__PACKAGE__->has_many('gifts', => 'Giftreg::DB::Gift',
                      'wanted_by_person_id');

# Custom accessor for last_update_dt that returns the date as 'Month DD, YYYY'
sub last_update_dt {
  my $self = shift;

  return strftime('%B %d, %Y', gmtime($self->get_column('last_update_dt')))
}

1;
