#!/usr/bin/perl

package DBIx::Class::PK::Sequence;

=head2 NAME

DBIx::Class::PK::Sequence - support for named sequences on inserting rows

=head2 SYNOPSYS

Allows you to use a standalone sequence (created with the standard CREATE
SEQUENCE command) to populate the primary key column of a table upon inserts.

=head2 USAGE

Add the B<sequence> key to your column definitions, for example:

    package My::Schema::Table;
    __PACKAGE__->load_components( qw/PK::Sequence Core/ );

    __PACKAGE__->add_column( 
        table_id => {
            data_type => 'integer',
            sequence => 'seq_table_pk',
            },
        username => {
            data_type => 'varchar',
            size => '32',
            },
        );
    __PACKAGE__->set_primary_key( qw/table_id/ );

Then, just insert rows as you would normally:

    My::Schema->populate( 'Table', [ [qw/username/], [qw/test1/], [qw/test2] ] );

This will call the driver function get_nextval with the sequence name specified and 
insert the row.

=head2 AUTHOR

Lee Standen <nom at standen.id.au>

=head2 ACKNOWLEDGEMENTS

mst, castaway, purl :) and anyone else in #dbix-class who helped out!
    
=cut

use base 'DBIx::Class';
use strict;
use warnings;

sub insert {
    my ($self, @rest) = @_;

    my $storage = $self->result_source->storage();
    $storage->ensure_connected;
    
    foreach my $col ($self->primary_columns) {
        next if $self->$col;
        if ($self->column_info($col)->{sequence}) {
            $self->throw_exception("Missing primary key, but Storage doesn't support nextval()") unless $storage->can('seq_nextval');
            my $id = $storage->seq_nextval( $self->column_info($col)->{sequence} );
            $self->store_column($col => $id);
        }
    }

    return $self->next::method(@rest);
}


1;
