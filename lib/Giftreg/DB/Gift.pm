package Giftreg::DB::Gift;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('giftreg_schema.gift');

__PACKAGE__->add_columns(qw/ gift_id short_desc long_desc location
                             wanted_by_person_id bought_by_person_id
                             priority_nbr /);
__PACKAGE__->set_primary_key('gift_id');

__PACKAGE__->belongs_to('wanted_by', => 'Giftreg::DB::Person',
                        'wanted_by_person_id');

__PACKAGE__->belongs_to('bought_by', => 'Giftreg::DB::Person',
                        'bought_by_person_id');

1;
