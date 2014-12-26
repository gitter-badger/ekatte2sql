#!/usr/lib/perl
# TODOS
# - require single command line argument
# - remove GetOptions and use ARGV instead

use utf8;
use strict;
use Data::Dumper;


use DBI;
use Encoding::FixLatin qw(fix_latin);
use Getopt::Long;


use lib ('./lib/perl');
use DataManager::Base;


my $ARGS = {
    'filename' => undef,
    'unique_key' => undef,
    'path' => undef,
};


GetOptions( 
    "filename=s" => \$$ARGS{filename}, 
    "unique-key=s" => \$$ARGS{unique_key}, 
    "path=s" => \$$ARGS{path}, 
);

die("No filename passed") unless defined $$ARGS{filename};

$$ARGS{path} //= `pwd`;


my $dbh = DBI->connect("DBI:XBase:$$ARGS{path}");
my $dmb = new DataManager::Base({
    dbh => $dbh,
    quote_identifiers => !!0,
    });

my $sth = $dbh->prepare("

    SELECT * 
    FROM  $$ARGS{filename}

");

$sth->execute; 

my $update_rows;
my $hash_last = {};
my $hash_count = {};
my $total_rows_count;

while (my $row = $sth->fetchrow_hashref)
{
    my $update_row = {};

    $total_rows_count++;

    for my $key (keys %{ $row })
    {
        my $cell = $$row{ $key };
        $$update_row{ $key } = fix_latin($cell);

        if(!defined $$ARGS{unique_key})
        {
            $$hash_count{ $key }++ unless($$hash_last{ $key } eq $cell);
            $$hash_last{ $key } = $cell;
        }
    } 

    my $update_row_str = $dmb->QuoteHash($update_row);

    if(defined $$ARGS{unique_key})
    {
        print STDERR "Update $$ARGS{filename} where $$ARGS{unique_key} = $$row{$$ARGS{unique_key}}: " . Dumper($update_row) . "\n";

        $dmb->Update($$ARGS{filename}, $update_row, {
            "$$ARGS{unique_key}" => $$row{$$ARGS{unique_key}}
            });
    }
    else
    {   
        push @{ $update_rows }, {
            fixed => $update_row,
            original => $row,
        };
    }
}


if(!defined $$ARGS{unique_key})
{
    my $unique_key;

    for my $key (%{ $hash_count })
    {
        if($$hash_count{ $key } == $total_rows_count)
        {
            $unique_key = $key;
            last;
        }
    }

    die("No unique key found") unless(defined $unique_key);

    for my $row_hash (@{ $update_rows })
    {
        print STDERR "Update $$ARGS{filename} where $unique_key => $$row_hash{original}{ $unique_key }: " . Dumper($$row_hash{fixed}) . "\n";;

        $dmb->Update($$ARGS{filename}, $$row_hash{fixed}, {
            "$unique_key" => $$row_hash{original}{ $unique_key },
        });
    }
}





