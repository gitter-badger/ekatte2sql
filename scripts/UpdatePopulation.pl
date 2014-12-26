#!/usr/lib/perl

use utf8;
use strict;
use Data::Dumper;


use JSON;
use Config::Any;
use DBI;


use AnyEvent;


use lib ('./lib/perl');
use DataManager::Stats;
use NSI::NRNM::Population;



my @filepaths = ('config/config.yml');
my $config = Config::Any->load_files({ files => \@filepaths, use_ext => !0, flatten_to_hash => !0 });
$config = $$config{'config/config.yml'};



binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';



my $dbh_config = "DBI:$$config{db}{driver}:dbname=$$config{db}{name};host=$$config{db}{host}";
print "Opening db handler: \"$dbh_config\"\n";
my $dbh = DBI->connect($dbh_config, $$config{db}{user}, $$config{db}{pass}, {
     AutoCommit => 0,
     RaiseError => 1,
 }) or die $DBI::errstr;


my $dm_stats = new DataManager::Stats({
		dbh => $dbh,
		adm_types => $$config{adm_types}
	});

my $nrnm_pop = new NSI::NRNM::Population({
	skip_rows => 2
});

my $sth = $dbh->prepare("

		SELECT * 
		FROM adm_units
		WHERE adm_type_id IN ($$config{adm_types}{city}, $$config{adm_types}{village}, $$config{adm_types}{monastery})

	");

$sth->execute;


my %surveys_cache;

use AnyEvent;
my $condvar = AnyEvent->condvar;
while(my $unit = $sth->fetchrow_hashref )
{
	$nrnm_pop->GetPopulation($$unit{ekatte})
		->then(sub {
				my ($result) = @_;

				for my $result_ekatte (keys $result )
				{
					for my $survey_year(keys $$result{ $result_ekatte } )
					{
						my $survey = $$result{ $result_ekatte }{$survey_year};

						if(!defined $surveys_cache{ $$survey{name} } )
						{
							$surveys_cache{ $$survey{name} } = $dm_stats->CreateOrUpdateSurvey({
								name => $$survey{name},
								descr => $$survey{name},
								survey_date => $$survey{date},
								organization_id => $$config{organizations}{NSI},
							});

						}

							# print STDERR Dumper \%surveys_cache;
						my $survey_id = $surveys_cache{ $$survey{name} }{id};
						my $indicator_id = 1;

						my $record = $dm_stats->CreateOrUpdateStatRecord({
							adm_unit_id => $$unit{id}, 
							survey_id => $survey_id, 
							indicator_id => $$config{indicators}{pop_total}, 
							value => $$survey{population}
						});

						print STDERR Dumper $record;
					}						
				}
				$dbh->commit;

				# print STDERR Dumper keys \%surveys_cache;	
				$condvar->send;
			});
	# last;
}
$condvar->recv;

print "Insert or update finished\n";