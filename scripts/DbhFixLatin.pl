#!/usr/lib/perl

use utf8;
use strict;
use Data::Dumper;


use DBI;
use Encoding::FixLatin qw(fix_latin);
use Getopt::Long;
use File::Basename;


use lib ('./lib/perl');
use DataManager::Base;

# WARNING - using unique key on multiple rows has some unexpected consequences like lost data
my $ARGS = {
    'unique_key' => undef,
};

GetOptions( 
    "unique-key=s" => \$$ARGS{unique_key}, 
);


my @files;
for my $path(@ARGV)
{
    push @files, $path if(-f $path);

    if(-d $path) 
    {
        @files = (@files, glob "$path/*.dbf");
    }
}

die("No filename passed") unless scalar(@files) >= 0;


for my $file (@files)
{
    my($filename, $path, $suffix) = fileparse($file);
    
    $filename = $filename . $suffix;

    my $dbh = DBI->connect("DBI:XBase:$path");
    my $dmb = new DataManager::Base({
        dbh => $dbh,
        quote_identifiers => !!0,
        });

    my $sth = $dbh->prepare("

        SELECT * 
        FROM  $filename

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
            print STDERR "Update $filename where $$ARGS{unique_key} = $$row{$$ARGS{unique_key}}: " . Dumper($update_row) . "\n";

            $dmb->Update($filename, $update_row, {
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
            print STDERR "Update $filename where $unique_key => $$row_hash{original}{ $unique_key }: " . Dumper($$row_hash{fixed}) . "\n";;

            $dmb->Update($filename, $$row_hash{fixed}, {
                "$unique_key" => $$row_hash{original}{ $unique_key },
            });
        }
    }
}