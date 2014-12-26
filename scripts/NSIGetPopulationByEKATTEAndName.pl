#!/usr/lib/perl

use utf8;
use strict;
use Data::Dumper;


use JSON;
use Getopt::Long;


use AnyEvent;


use lib ('./lib/perl');
use GeoStats::NSI::NRNM::Population;


binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';


my $ARGS = {
	'ekatte' => undef,
};


GetOptions( 
    "ekatte=s" => \$$ARGS{ekatte}, 
);


my $condvar = AnyEvent->condvar;
my $nsiq = new GeoStats::NSI::NRNM::Population({
	skip_rows => 2
	});

my $result = $nsiq->GetPopulation($$ARGS{date})
	->then(sub {
			my ($res) = @_;
			print to_json( $res, { pretty => 1 } );
			$condvar->send;
		}, sub {
			print "It's impossible to see this";
			$condvar->send;
		});


$condvar->recv;