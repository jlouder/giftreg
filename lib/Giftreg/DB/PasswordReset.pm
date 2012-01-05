package Giftreg::DB::PasswordReset;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('password_reset');

__PACKAGE__->add_columns(
  'person_id' => {
    data_type      => 'number',
    is_foreign_key => 1,
  },
  'secret' => {
    data_type      => 'varchar',
    size           => 100,
  },
  'expire_dt' => {
    data_type      => 'number',
  },
);

__PACKAGE__->set_primary_key('secret');

__PACKAGE__->belongs_to('person', => 'Giftreg::DB::Person',
                        'person_id');

1;
