package DataManager::AdmUnits;

use utf8;
use strict;
use Data::Dumper;


use lib ('.');

#
#	dbh - DBI handler
#	adm_types - hash ref key:adm_type => value:adm_type_id
#		{ province => 5 }
#



sub new {
    my ($class, $options) = @_;

    my %base = (
    	dbh => undef,
    	adm_types => undef,
    	%{ $options },
	);

	die("DBH not set") unless defined $base{dbh};
	die("DBH not set") unless ref $base{adm_types} eq "HASH";

    my $self = \%base;

    bless $self, $class;


    return $self;
}


sub CreateOrUpdateAdmUnitByEKATTE($$)
{
	my ($self, $adm_unit) = @_;
	my @filter_keys = qw(id name ekatte ekatte_name);
	my $filtered_adm_unit = $self->FilterHash($adm_unit, \@filter_keys);
	my $parent;
	my $where;
	my $sth;

	if (defined $$adm_unit{PARENT}) {
		$parent = $self->GetAdmUnitByEKATTE($$adm_unit{PARENT});
			die("Parent not found for " . Dumper($adm_unit)) unless defined $parent;
		$$filtered_adm_unit{ parent_id } = $$parent{id};
	} 

	$$filtered_adm_unit{ adm_type_id } = $$self{adm_types}{ $$adm_unit{TYPE} };
	$$filtered_adm_unit{ name } = $$adm_unit{ $$adm_unit{TYPE} };

	if($$adm_unit{ekatte_name} =~ /^\d+$/)
	{
		$$filtered_adm_unit{ekatte} = $$filtered_adm_unit{ekatte_name};
		$$where{ekatte} = $$filtered_adm_unit{ekatte_name};
		delete $$filtered_adm_unit{ekatte_name};
	}
	else
	{
		$$where{ekatte_name} = $$adm_unit{ekatte_name};
	}

	if($$filtered_adm_unit{adm_type_id} == $$self{adm_types}{city} || $$filtered_adm_unit{adm_type_id} == $$self{adm_types}{village})
	{
		$$where{adm_type_id} = [$$self{adm_types}{city}, $$self{adm_types}{village}];
	}
	else
	{
		$$where{adm_type_id} = $$filtered_adm_unit{adm_type_id};
	}


	my @where = @{ $self->QuoteHash($where) };
	# push @where, 'adm_type_id != ' . $$self{adm_types}{council} unless $$filtered_adm_unit{adm_type_id} == $$self{adm_types}{council};
	my $where_str =  join ' AND ', @where;
	my $values_str =  join ', ', @{ $self->QuoteHash($filtered_adm_unit) };

	print STDERR "Updating where: $where_str \n";

	$sth = $$self{dbh}->prepare("

		UPDATE adm_units
		SET $values_str
		WHERE $where_str 

	");

	$sth->execute;

	die ('Multiple rows updated ', $sth->rows) if $sth->rows > 1;
	
	if ($sth->rows == 0)
	{
		print STDERR "Update failed, inserting \n";
		my @keys = keys $filtered_adm_unit;
		my $cols_str = join ', ', @keys;
		my @values;
		
		for my $key (@keys)
		{
			push @values, $$self{dbh}->quote($$filtered_adm_unit{$key});
		}

		$values_str = join ', ', @values;

		$sth = $$self{dbh}->prepare("

			INSERT INTO adm_units
			($cols_str)
			VALUES 
			($values_str)
		
		");
		$sth->execute;

		die ('Failed insert') if ($sth->rows != 1);
	}


	return 1;
}


sub GetAdmUnitByEKATTE($$)
{
	my ($self, $ekatte) = @_;
	my $where_clause;
	my $adm_unit;

	if ($ekatte =~ /^\d+$/)
	{
		$where_clause .= "ekatte = "
	}
	else
	{
		$where_clause .= "ekatte_name = "
	}


	$where_clause .= $$self{dbh}->quote($ekatte);
	$adm_unit = $$self{dbh}->selectrow_hashref("
		
		SELECT *
		FROM adm_units
		WHERE $where_clause
		
		");

	return $adm_unit;
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
		$condition .= $$self{dbh}->quote_identifier($key);
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

1;