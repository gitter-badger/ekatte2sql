#!/usr/lib/perl

use utf8;
use strict;
use Data::Dumper;


use JSON;
use Getopt::Long;
use Config::Any;
use DBI;

use AnyEvent;


use lib ('./lib/perl');
use DataManager::AdmUnits;



my @filepaths = ('config/config.yml');
my $config = Config::Any->load_files({ files => \@filepaths, use_ext => !0, flatten_to_hash => !0 });
$config = $$config{'config/config.yml'};



binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';


my $ARGS = {
	'filename' => undef,
};


GetOptions( 
    "filename=s" => \$$ARGS{filename}, 
);



my $json_text = do {
   open(my $json_fh, "<:encoding(UTF-8)", $$ARGS{filename})
      or die("Can't open \$filename\": $!\n");
   local $/;
   <$json_fh>
};

print "Parsing JSON...\n";
my $json = JSON->new;
my $data = $json->decode($json_text);


my $dbh_config = "DBI:$$config{db}{driver}:dbname=$$config{db}{name};host=$$config{db}{host}";
print "Opening db handler: \"$dbh_config\"\n";
my $dbh = DBI->connect($dbh_config, $$config{db}{user}, $$config{db}{pass}, {
     AutoCommit => 0,
     RaiseError => 1,
 }) or die $DBI::errstr;


my $dm_adm_units = new DataManager::AdmUnits({
		dbh => $dbh,
		adm_types => $$config{adm_types},
	});


for my $unit ( @{$data} )
{
	$dm_adm_units->CreateOrUpdateAdmUnitByEKATTE($unit);

	$dbh->commit;	
}

print "Insert or update finished\n";