package GeoStats::DataManager::Base;

use utf8;
use strict;
use Data::Dumper;


use lib ('.');


sub new {
    my ($class, $options) = @_;

    my %base = (
        dbh => undef,
        quote_identifiers => !0,
        %{ $options },
    );

    die("DBH not set") unless defined $base{dbh};

    my $self = \%base;

    bless $self, $class;

    return $self;
}


sub FilterHash($$)
{
    my ($self, $hash, $arr) = @_;
    my $result = {};

    for my $key (@{ $arr }) 
    {
        $$result{$key} = $$hash{$key};
        delete $$result{$key} if not defined $$result{$key};
    }

    return $result;
}


sub QuoteHash($$)
{
    my ($self, $hash) = @_;
    my @conditions;

    for my $key (keys %{ $hash })
    {
        my $condition;
        $condition .= ($$self{quote_identifiers}) ? $$self{dbh}->quote_identifier($key) : $key;
        if(ref $$hash{ $key } eq 'ARRAY')
        {
            my @values;
            $condition .= ' IN (';
            
            for my $value (@{ $$hash{ $key } })
            {
                push @values, $$self{dbh}->quote($value)
            }

            $condition .= join ', ', @values;
            $condition .= ' ) ';
        }
        else
        {
            $condition .= ' = ';
            $condition .= $$self{dbh}->quote($$hash{ $key });
        }
        push @conditions, $condition;
    }

    return \@conditions;
}

sub Update($$$;$$)
{
    my ($self, $table, $row, $where, $return) = @_;
    my $sth;
    my $row_str;
    my $where_str;
    my $return_str;
    my $query;
    
    $row_str = join ', ', @{ $self->QuoteHash($row) };
    $where_str = join 'AND', @{ $self->QuoteHash($where) } if(defined $where);
    $table = $$self{dbh}->quote_identifier($table) if $$self{quote_identifiers};


    $query .= "UPDATE $table \n";
    $query .= "SET $row_str \n";
    $query .= "WHERE $where_str \n" if(defined $where);
    $query .= "$return_str" if(0);

    $sth = $$self{dbh}->prepare( $query );
    $sth->execute;

    return $sth->rows;
}

1;