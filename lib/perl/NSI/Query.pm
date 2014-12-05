package NSI::Query;

use utf8;
use strict;
use Data::Dumper;


use AnyEvent::HTTP;
use AnyEvent::Promises qw(deferred merge_promises);


use lib ('/home/suricactus/work/ekatte2sql/lib/perl');
use NSI::Interface;


use base 'NSI::Interface';


sub new {
    my ($class, $options) = @_;


	my $self = $class->SUPER::new($options);


    return $self;
}



sub GetTreeOfProvinces($$)
{
	my ($self, $date) = @_;
	my $dfd = deferred;


	$self->GetProvinces($date)
		->then(sub {
				my ($provinces) = @_;

				$self->GetMunicipalities($date, $provinces)
					->then(sub {
						my ($municipalities) = @_;
						
						$dfd->resolve ($provinces);
					});
			});


	return $dfd->promise;
}



sub GetTreeOfMunicipalities($$)
{	
	my ($self, $date, $provinces) = @_;
	my $dfd = deferred;


	$self->GetMunicipalities($date, $provinces)
		->then(sub {
			my ($municipalities) = @_;
			
			$dfd->resolve ($provinces);
		});

	return $dfd->promise;			
}



sub GetProvinces($$)
{
	my ($self, $date) = @_;
	my $dfd = deferred;

	# Тази заявка взима всички области към даден период
	my $req = $self->Request({
		f => 3, 
		date => "04.12.2014", 
		hierarchy=> 1
	});

	return $req;
}



sub GetMunicipalities($$)
{
	my ($self, $date, $provinces) =  @_;
	my $dfd = deferred;
	my $municipalities = [];
	my @requests;

	
	$provinces = $$self->GetProvinces() unless defined $provinces;


	for my $region_row (@{ $provinces })
	{
		for my $href_key (keys %{ $$region_row{HREFS} })
		{
			if ($href_key == 'name')
			{
				my $href = $$region_row{HREFS}{$href_key};
				my $uri = $self->ParseURI($href);

				# Тази заявка взима всички общини към даден период
				my $req = $self->Request($uri)
					->then(sub {
							my ($table) = @_;
							push @{ $municipalities }, $table;
						});
				push @requests, $req;
			}
		}
	}


	my $merged_req = merge_promises (@requests)
		->then(sub {
				$dfd->resolve ($municipalities);
			});

	return $merged_req;
}


sub ParseDate($$)
{
	my ($self, $date) = @_;

	$date =~ s/(\d{4})-(\d{2})-(\d{2})/$3.$2.$1/g;

	return $date;
}

1;