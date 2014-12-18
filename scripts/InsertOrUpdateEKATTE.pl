#!/usr/lib/perl

use utf8;
use strict;
use Data::Dumper;


use JSON;
use Getopt::Long;
use DBI;


use AnyEvent;


use lib ('./lib/perl');
use DataManager::AdmUnits;


use constant {
	ADM_TYPE_EU_REGION => 7,
	ADM_TYPE_REGION => 6,
	ADM_TYPE_PROVINCE => 5,
	ADM_TYPE_MUNICIPALITY => 4,
	ADM_TYPE_COUNCIL => 9,
	ADM_TYPE_CITY => 3,
	ADM_TYPE_MONASTERY => 2,
	ADM_TYPE_VILLAGE => 1,
};


binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';


my $ARGS = {
	'filename' => undef,
	'db_driver' => 'Pg',
	'db_name' => undef,
	'db_user' => undef,
	'db_pass' => undef,
	'db_host' => 'localhost',
};


GetOptions( 
    "filename=s" => \$$ARGS{filename}, 
    "db-driver=s" => \$$ARGS{db_driver}, 
    "db-name=s" => \$$ARGS{db_name},
    "db-user=s" => \$$ARGS{db_user},
    "db-pass=s" => \$$ARGS{db_pass},
    "db-host=s" => \$$ARGS{db_host},
);

$$ARGS{db_driver} = "Pg" if $$ARGS{db_driver} =~ /pg|postgres|psql|postgresql/gi;


my $json_text = do {
   open(my $json_fh, "<:encoding(UTF-8)", $$ARGS{filename})
      or die("Can't open \$filename\": $!\n");
   local $/;
   <$json_fh>
};

print "Parsing JSON...\n";
my $json = JSON->new;
my $data = $json->decode($json_text);


my $dbh_config = "DBI:$$ARGS{db_driver}:dbname=$$ARGS{db_name};host=$$ARGS{db_host}";
print "Opening db handler: \"$dbh_config\"\n";
my $dbh = DBI->connect($dbh_config, $$ARGS{db_user}, $$ARGS{db_pass}, {
     AutoCommit => 0,
     RaiseError => 1,
 }) or die $DBI::errstr;


my $dm_adm_units = new DataManager::AdmUnits({
		dbh => $dbh,
		adm_types => {
			eu_region => ADM_TYPE_EU_REGION,
			region => ADM_TYPE_REGION,
			province => ADM_TYPE_PROVINCE,
			municipality => ADM_TYPE_MUNICIPALITY,
			council => ADM_TYPE_COUNCIL,
			village => ADM_TYPE_VILLAGE,
			monastery => ADM_TYPE_MONASTERY,
			city => ADM_TYPE_CITY,
		}
	});


for my $unit ( @{$data} )
{
	$dm_adm_units->CreateOrUpdateAdmUnitByEKATTE($unit);	
	# print Dumper $unit;	
}
print 1111111111100;