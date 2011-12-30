package Giftreg::DB::PasswordReset;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('giftreg_schema.password_reset');

__PACKAGE__->add_columns(qw/ person_id secret expire_dt /);
__PACKAGE__->set_primary_key('secret');

__PACKAGE__->belongs_to('person', => 'Giftreg::DB::Person',
                        'person_id');

1;
