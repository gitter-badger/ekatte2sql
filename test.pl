#!/usr/lib/perl

use utf8;
use strict;

use Data::Dumper;
use Spreadsheet::Read;
use DBI;
use JSON;
use Getopt::Long;


use lib ('/home/suricactus/work/ekatte2sql/lib/perl');
use NSI::Query;


binmode STDIN, ':utf8';
binmode STDOUT, ':utf8';



# print Dumper 
# $result;



# use constant {
# 	ADM_TYPE_CITY => 1,
# 	ADM_TYPE_MONASTERY => 2,
# 	ADM_TYPE_VILLAGE => 3,
# 	ADM_TYPE_PROVINCE => 5,
# 	ADM_TYPE_MUNICIPILITY => 4,
# };



use AnyEvent;


my $condvar = AnyEvent->condvar;
my $nsiq = new NSI::Query;

my $result = $nsiq->GetTreeOfProvinces($condvar)
	->then(sub {
			print "1\n";
			$condvar->send;
		}, sub {
			print "2\n";
			$condvar->send;
		});




$condvar->recv;