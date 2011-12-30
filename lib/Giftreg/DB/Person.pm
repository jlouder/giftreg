package Giftreg::DB::Person;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('giftreg_schema.person');

__PACKAGE__->add_columns(qw/ person_id email_address password
                             last_update_dt /);
__PACKAGE__->set_primary_key('person_id');
__PACKAGE__->add_unique_constraint([ qw/ email_address / ]);

__PACKAGE__->has_many('gifts', => 'Giftreg::DB::Gift',
                      'wanted_by_person_id');

1;
