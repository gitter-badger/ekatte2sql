#!/usr/lib/perl

use utf8;
use strict;
use Data::Dumper;


use JSON;
use Getopt::Long;


use AnyEvent;


use lib ('./lib/perl');
use NSI::NRNM::Extract;


binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';
binmode STDERR, ':utf8';


my $ARGS = {
	'date' => '',
};


GetOptions( 
    "date=s" => \$$ARGS{date}, 
);

$$ARGS{date} = $$ARGS{date} || `date -Idate`;

die("Invalid date") unless($$ARGS{date} =~ /^\d{4}-\d{2}-\d{2}$/);
print STDERR "Requesting for date $$ARGS{date}";


my $condvar = AnyEvent->condvar;
my $nsiq = new NSI::NRNM::Extract({
	skip_rows => 2
	});

my $result = $nsiq->GetTreeOfProvinces($$ARGS{date})
	->then(sub {
			my ($res) = @_;
			print to_json( $res, { pretty => 1 } );
			$condvar->send;
		}, sub {
			print "It's impossible to see this";
			$condvar->send;
		});


$condvar->recv;