package Hash::Storage::Driver::DBI;

use v5.10;
use strict;
use warnings;

use Carp qw/croak/;
use Query::Abstract;

use base "Hash::Storage::Driver::Base";

our $VERSION = 0.01;

sub new {
    my ($class, %args) = @_;

    my $self = $class->SUPER::new(%args);
    croak "DBH REQUIRED" unless $self->{dbh};
    croak "TABLE REQUIRED" unless $self->{table};

    return $self;
}

sub init {
    my ($self) = @_;
    $self->{query_abstract} = Query::Abstract->new( driver => [
        'SQL' => [ table => $self->{table} ]
    ] );
}

sub get {
    my ( $self, $id ) = @_;

    my $sth = $self->{dbh}->prepare_cached("SELECT * FROM $self->{table} WHERE $self->{key_column} = ?");
    $sth->execute($id);
    
    my $row = $sth->fetchrow_hashref();
    $sth->finish();

    my $serialized = $row->{ $self->{data_column} };
    return $self->{serializer}->deserialize($serialized);
}

sub set {
    my ( $self, $id, $fields ) = @_;
    return unless keys %$fields;

    my $data = $self->get($id);
    my $is_create =  $data ? 0 : 1;

    # Prepare serialized data
    $data ||= {};
    @{$data}{ keys %$fields } = values %$fields;

    my $serialized = $self->{serializer}->serialize($data);

    # Prepare index columns
    my @columns = grep { $_ ~~ $self->{index_columns} } keys %$fields;
    my @values = @{$fields}{@columns};

    # Add serialized column
    push @columns, $self->{data_column};
    push @values, $serialized;

    my $sql = '';    
    my $bind_values = [@values];

    if ($is_create) {
        my $values_cnt = @columns + 1;
        $sql = "INSERT INTO $self->{table}(" . join(', ', @columns, $self->{key_column} ) . ") VALUES(" . join(', ', ('?')x $values_cnt) . ")";
        push @$bind_values, $id;
    } else {
        my $update_str = join(', ', map { "$_=?" } @columns );
        $sql = "UPDATE $self->{table} SET $update_str WHERE $self->{key_column} = ?";
        push @$bind_values, $id;
    }

    my $sth = $self->{dbh}->prepare_cached($sql);

    $sth->execute(@$bind_values);
    $sth->finish();
}

sub del {
    my ( $self, $id ) = @_;
    my $sql = "DELETE FROM $self->{table} WHERE $self->{key_column}=?";

    my $sth = $self->{dbh}->prepare_cached($sql);
    $sth->execute($id);
    $sth->finish();
}

sub list {
    my ( $self, @query ) = @_;
    
    my ($sql, $bind_values) = $self->{query_abstract}->convert_query(@query);
    
    my $sth = $self->{dbh}->prepare_cached($sql);
    $sth->execute(@$bind_values);

    my $rows = $sth->fetchall_arrayref({});
    $sth->finish();


    return [ map { $self->{serializer}->deserialize(
        $_->{ $self->{data_column} }
    ) } @$rows ];
}

sub count {
    my ( $self, $filter ) = @_;
    my ($where_str, $bind_values) = $self->{query_abstract}->convert_filter($filter);

    my $sql = "SELECT COUNT(*) FROM $self->{table} $where_str";

    my $sth = $self->{dbh}->prepare_cached($sql);
    $sth->execute(@$bind_values);

    my $row = $sth->fetchrow_arrayref();
    return $row->[0];
} 


1;
