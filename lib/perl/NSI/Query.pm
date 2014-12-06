package NSI::Query;

use utf8;
use strict;
use Data::Dumper;


use AnyEvent::HTTP;
use AnyEvent::Promises qw(deferred merge_promises);


use lib ('/home/suricactus/work/ekatte2sql/lib/perl');
use NSI::Interface;


use base 'NSI::Interface';


use constant Q_PARAM_HIERARCHY_MUNICIPALITY => 1;
use constant Q_PARAM_HIERARCHY_COUNCIL => 5;


sub new {
    my ($class, $options) = @_;


	my $self = $class->SUPER::new($options);


    return $self;
}



sub GetTreeOfProvinces($$)
{
	my ($self, $date) = @_;
	my $dfd = deferred;
	my @result;

	$self->GetProvinces($date)
		->then(sub {
				my ($provinces) = @_;

				@result = (@result, @{ $provinces });

				$provinces = [$$provinces[5]]; #TODO delete

				$self->GetTreeOfMunicipalities($date, $provinces)
						->then(sub {
							my ($municipalities) = @_;

							print STDERR '!!!!!!!!';

							@result = (@result, @{ $municipalities });
							
							$dfd->resolve ( \@result );
						});
			});


	return $dfd->promise;
}



sub GetTreeOfMunicipalities($$$)
{	
	my ($self, $date, $provinces) = @_;
	my $dfd = deferred;
	my @result;


	return $self->GetMunicipalities($date, $provinces)
		->then(sub {
			my ($municipalities) = @_;

			$municipalities = [$$municipalities[5]]; #TODO delete

			@result = (@result, @{ $municipalities });

			return $self->GetTreeOfCouncils($date, $municipalities)
				->then( sub {
					my ($councils_children) = @_;
					my %undirect_settlements;

					@result = (@result, @{ $councils_children });

					for my $councils_child (@{ $councils_children })
					{
						$undirect_settlements{$$councils_child{ekatte_name}} = 1 if $$councils_child{TYPE} eq 'settlement';
					}

					return $self->GetSettlements($date, $municipalities, !!0)
						->then(sub {
							my ($settlements) = @_;

							for my $settlement (@{ $settlements })
							{
								if (defined $undirect_settlements{$$settlement{ekatte_name}})
								{
									next;
								}

								push @result, $settlement;
							}

							return \@result;
						});
				})
		});			
}


sub GetTreeOfCouncils($$$)
{
	my ($self, $date, $municipalities) = @_;
	my $dfd = deferred;
	my @result;

	return $self->GetCouncils($date, $municipalities)
		->then(sub {
			my ($councils) = @_;

			@result = (@result, @{ $councils });

			return $self->GetSettlements($date, $councils, !0)
				->then( sub {
					my ($settlements) = @_;

					@result = (@result, @{ $settlements });

					return \@result;
				})
		});
}


sub GetProvinces($$)
{
	my ($self, $date) = @_;
	my $dfd = deferred;

	# Тази заявка взима всички области към даден период
	my $req = $self->Request({
		f => 3, 
		date => "04.12.2014", 
		hierarchy=> 5,
	})
		->then(sub {
			my ($provinces) = @_;

			for my $row (@{ $provinces })
			{
				# print STDERR Dumper ;
				$$row{TYPE} = "province";		
				print STDERR "Province $$row{name}\n";
			}

			return $provinces;
		});

	return $req;
}



sub GetMunicipalities($$$)
{
	my ($self, $date, $provinces) =  @_;
	my $dfd = deferred;
	my $municipalities = [];
	my @requests;


	if (not defined $provinces)
	{
		$self->GetProvinces($date)
			->then(sub { $dfd->resolve(@_) })
	}
	else
	{
		$dfd->resolve($provinces);
	}


	return $dfd->promise->then(sub {
		my ($provinces) = @_;

		for my $province (@{ $provinces })
		{
			for my $href_key (keys %{ $$province{HREFS} })
			{
				if ($href_key == 'name')
				{
					print STDERR "Get municipalities: ";
					my $href = $$province{HREFS}{$href_key};
					my $uri = $self->ParseURI($href);
					my $req = $self->Request($uri)
						->then(sub {
								my ($table) = @_;

								for my $row (@{ $table })
								{
									$$row{TYPE} = "municipality";				
									print STDERR "Municipality $$row{name}\n";
								}

								$municipalities = [@{ $municipalities }, @{ $table }];
							});

					push @requests, $req;
				}
			}
		}

			

		return merge_promises (@requests)
			->then(sub { return $municipalities });
	});
}




sub GetCouncils($$$)
{
	my ($self, $date, $municipalities) =  @_;
	my $dfd = deferred;
	my $councils = [];
	my @requests;

	
	if (not defined $municipalities)
	{
		$self->GetMunicipalities($date)
			->then(sub { $dfd->resolve(@_) })
	}
	else
	{
		$dfd->resolve($municipalities);
	}


	return $dfd->promise->then(sub {
		my ($municipalities) = @_;

		for my $municipality (@{ $municipalities })
		{
			for my $href_key (keys %{ $$municipality{HREFS} })
			{
				if ($href_key == 'name')
				{
					print STDERR "Get councils: ";

					my $href = $$municipality{HREFS}{$href_key};
					my $uri = $self->ParseURI($href);
					my $req = $self->Request($uri)
						->then(sub {
								my ($table) = @_;

								for my $row (@{ $table })
								{
									$$row{TYPE} = "councils";
									print STDERR "Council $$row{name}\n";
								}

								$councils = [@{ $councils }, @{ $table }];
							});

					push @requests, $req;
				}
			}
		}


		return merge_promises (@requests)
			->then(sub { return $councils });
	});
}


sub GetSettlements($$$$)
{
	my ($self, $date, $parents, $by_council) =  @_;
	my $dfd = deferred;
	my $settlements = [];
	my @requests;


	if (not defined $parents)
	{
		$parents = ($by_council) ? $self->GetCouncils($date) : $self->GetMunicipalities($date);
		$parents->then(sub { $dfd->resolve(@_) })
	}
	else
	{
		$dfd->resolve($parents);
	}
	

	return $dfd->promise->then(sub {
		my ($parents) = @_;

		for my $parent (@{ $parents })
		{
			for my $href_key (keys %{ $$parent{HREFS} })
			{
				if ($href_key == 'name')
				{
					print STDERR "Get settlements by ", (($by_council) ? "council" : "municipality"), ": ";
					my $href = $$parent{HREFS}{$href_key};
					my $uri = $self->ParseURI($href);
					my $query_params = $self->ParseQueryParams($uri);

					$$query_params{hierarchy} = Q_PARAM_HIERARCHY_MUNICIPALITY;

					my $req = $self->Request($uri)
						->then(sub {
								my ($table) = @_;

								for my $row (@{ $table })
								{
									$$row{TYPE} = "settlement";
									print STDERR "Settlement $$row{name}\n";	
								}

								push @{ $settlements }, $table;
							});

					push @requests, $req;
				}
			}
		}


		return merge_promises (@requests)
			->then(sub { return $settlements; });
	});
}


sub ParseDate($$)
{
	my ($self, $date) = @_;

	$date =~ s/(\d{4})-(\d{2})-(\d{2})/$3.$2.$1/g;

	return $date;
}

1;