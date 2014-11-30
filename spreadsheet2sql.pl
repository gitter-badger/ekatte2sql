#!/usr/lib/perl
use utf8;
use strict;

use Data::Dumper;
use Spreadsheet::Read;
use DBI;
use JSON;
use Getopt::Long;

binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';



our ($db, $input_file, $input_dir, $schema);



$db = {
    driver => "Pg",
    name => "ekatte",
    user => undef,
    pass => undef,
    host => "localhost",
};

GetOptions( 
    "db-driver=s" => \$$db{driver}, 
    "db-name=s" => \$$db{name},
    "db-user=s" => \$$db{user},
    "db-pass=s" => \$$db{pass},
    "db-host=s" => \$$db{host},
    "input-dir=s" => \$input_dir,
    "input-file=s" => \$input_file,
          );

$$db{driver} = "Pg" if $$db{driver} =~ /pg|postgres|psql|postgresql/gi;



# Parse input json schema
my $json_text = do {
    print "Opening \"$input_file\" to read JSON\n";
    open(my $json_fh, "<:encoding(UTF-8)", $input_file)
        or die("Can't open \"$input_file\": $!\n");
    local $/;
    <$json_fh>
};

print "Parsing JSON...\n";
my $json = JSON->new;
$schema = $json->decode($json_text);



# Open db handler
my $dbh_config = "DBI:$$db{driver}:dbname=$$db{name};host=$$db{host}";
print "Opening db handler: \"$dbh_config\"\n";
my $dbh = DBI->connect($dbh_config, $$db{user}, $$db{pass}, {
     AutoCommit => 0,
     RaiseError => 1,
 }) or die $DBI::errstr;
 


print "Parsing schema \n";
# Actual script
for my $file_schema (@{ $schema })
{
    next if $$file_schema{disabled};
    my @insert_data;
    my @insert_cols;

    my $filename = "$input_dir$$file_schema{name}"; 
        
    print "Parsing file $filename\n";
    
    my $book = ReadData($filename, 
        attr => 1, 
    );
    my $sheet = $book->[1]{cell};
    my @cols = @{ $sheet };
    my $data = [];

    # print Dumper($book);

    # convert to normal table
    for my $index_col (1 .. $#cols) 
    {
        my $col = $cols[$index_col];
        my @col = @{ $col };
        my $col_name;

        for my $index (1 .. $#col) 
        {
            if($index == 1)
            {
                $col_name = $col[$index];
                next; 
            }

            $$data[$index - 1] = {} unless defined $$data[$index - 1];
            $$data[$index - 1]{$col_name} = $col[$index];
        }  
    }

    # sort columns
    for my $col (sort keys $$file_schema{cols})
    {
        push @insert_cols, $dbh->quote_identifier($col);
    }

    # match rows to insert data
    my $row_index = -1;
    for my $row (@{ $data })
    {
        if ($row_index == -1 || ($$file_schema{skip_rows} && $row_index < $$file_schema{skip_rows}))
        {
            $row_index++;
            next;
        }
        my @insert_row;

        for my $col (sort keys $$file_schema{cols})
        {
            my $col_value = $$file_schema{cols}{$col};

            if (ref $col_value eq "HASH")
            {
                my $condition_index;
                my $conditions;
                for my $condition (@{ $$col_value{where} })
                {
                    my $str;
                    my $operator = $$condition[2] =~ /[=\!><]+/ || '=';
                    my $condition_value;

                    if (ref $$condition[1] eq "HASH")
                    {
                        $condition_value = $$row{ ExtractColumnFromString($$condition[1]{col}) };
                        
                        # print $$condition[1]{pattern};                        
                        if ($condition_value =~ /$$condition[1]{pattern}/)
                        {
                            $condition_value = $1;
                        }
                    }
                    else
                    {
                        $condition_value = $$row{ ExtractColumnFromString($$condition[1]) };
                    }
                    $str .= $$condition[3] || ' AND ' if $condition_index;
                    $str .= $dbh->quote_identifier($$condition[0]);
                    $str .= $operator;
                    $str .= $dbh->quote($condition_value);

                    $conditions .= $str;
                    $condition_index++;
                }

                my $table = $dbh->quote_identifier($$col_value{table});
                my $sth = $dbh->prepare("

                        SELECT $$col_value{field}
                        FROM $table
                        WHERE $conditions
                        ORDER BY id DESC

                        ");
                $sth->execute();

                my $result = $sth->fetchrow_hashref;

                die "No required value in $$col_value{field} where $conditions" if ($$col_value{required} && !$$result{ $$col_value{field} });

                push @insert_row, $dbh->quote( $$result{ $$col_value{field} } );
            }
            elsif (my $extracted_col = ExtractColumnFromString($col_value))
            {
                push @insert_row, $dbh->quote( $$row{$extracted_col} || undef );
            }
            else
            {
                push @insert_row, $dbh->quote( $col_value || undef );
            }
        }

        push @insert_data, \@insert_row;
    }

#    print Dumper(\@insert_data);   
    ExecuteQuery($$file_schema{table}, \@insert_cols, \@insert_data);
}

print "Finish\n";

sub ExtractColumnFromString($)
{
    my ($str) = @_;
    return ($str =~ /^==([a-zA-Z0-9_]+)$/) ? $1 : undef;
}

sub ExecuteQuery($$$)
{
    my ($table, $cols, $values) = @_;
    my $sth;
    my $cols_str = join ', ', @{ $cols };
    my @values_arr;
    my $values_str;

    print "Prepare query for table $table\n";

    for my $value (@{ $values })
    {
        my $value_str;
        $value_str .= "( ";
        $value_str .= join ', ', @{ $value };
        $value_str .= " )";
        push @values_arr, $value_str;
    }

    $values_str = join ', ', @values_arr;
    $table = $dbh->quote_identifier($table);
   
    $sth = $dbh->prepare("

        INSERT INTO $table
        ( $cols_str )
        VALUES
        $values_str

    ");

    $sth->execute();
    $dbh->commit;

    print "Query execited and commited\n";
}

