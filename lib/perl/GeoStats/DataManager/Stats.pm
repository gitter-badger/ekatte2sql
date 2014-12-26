package GeoStats::DataManager::Stats;

use utf8;
use strict;
use Data::Dumper;


use lib ('.');


sub new {
    my ($class, $options) = @_;

    my %base = (
    	dbh => undef,
    	%{ $options },
	);

	die("DBH not set") unless defined $base{dbh};

    my $self = \%base;

    bless $self, $class;


    return $self;
}


sub CreateOrUpdateSurvey($$)
{
	my ($self, $survey) = @_;
	my @filter_keys = qw(id name descr survey_date organization_id);
	my $filtered_survey = $self->FilterHash($survey, \@filter_keys);
	my $where;

	if(defined $$filtered_survey{id})
	{
		$$where{id} = $$filtered_survey{id};
	}
	else
	{
		$$where{survey_date} = $$filtered_survey{survey_date};
		$$where{name} = $$filtered_survey{name};
	}

	return $self->CreateOrUpdateRow('stat_surveys', $filtered_survey, $where);
}

sub CreateOrUpdateStatRecord($$)
{
	my ($self, $record) = @_;
	my @filter_keys = qw(id adm_unit_id survey_id indicator_id value);
	my $filtered_record = $self->FilterHash($record, \@filter_keys);
	my $where;

	if(defined $$filtered_record{id})
	{
		$$where{id} = $$filtered_record{id};
	}
	else
	{
		$$where{adm_unit_id} = $$filtered_record{adm_unit_id};
		$$where{survey_id} = $$filtered_record{survey_id};
		$$where{indicator_id} = $$filtered_record{indicator_id};
	}

    return $self->CreateOrUpdateRow('stat_records', $filtered_record, $where);
}


sub CreateOrUpdateRow($$$)
{
	my ($self, $table, $data, $where) = @_;

	die("Undefined where clause") unless defined $where;

	my $quoted_data = $self->QuoteHash($data);
	my $where_str = join ' AND ', @{ $self->QuoteHash($where) };
	my $values_str =  join ', ', @{ $quoted_data };
	my $sth;

	$table = $$self{dbh}->quote_identifier($table);
    $sth = $$self{dbh}->prepare("

        UPDATE $table
        SET $values_str
        WHERE $where_str 
        RETURNING *

    ");

    $sth->execute;

    die ('Multiple '. $sth->rows .' rows updated in table $table where $where_str') if $sth->rows > 1;

    if($sth->rows == 0)
    {
        # print STDERR "Update failed, inserting $values_str \n";
        my @values;
        my @cols;
        
        for my $key (keys $data)
        {
        	push @cols, $$self{dbh}->quote_identifier( $key );
			push @values, $$self{dbh}->quote($$data{ $key });
        }

        my $cols_str = join ', ', @cols;
        $values_str = join ', ', @values;


        $sth = $$self{dbh}->prepare("

            INSERT INTO $table
            ($cols_str)
            VALUES 
            ($values_str)
        	RETURNING *

        ");

        $sth->execute;

        die ('Failed insert values $values_str') if ($sth->rows != 1);
    }


    return $sth->fetchrow_hashref;
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
				push @values, $$self{dbh}->quote($value);
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