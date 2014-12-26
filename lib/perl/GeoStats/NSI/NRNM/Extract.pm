package GeoStats::NSI::NRNM::Extract;

use utf8;
use strict;
use Data::Dumper;


use AnyEvent::HTTP;
use AnyEvent::Promises qw(deferred merge_promises);


use lib ('.');
use GeoStats::NSI::NRNM::Interface;


use base 'GeoStats::NSI::NRNM::Interface';


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

            $self->GetTreeOfMunicipalities($date, $provinces)
                ->then(sub {
                    my ($municipalities) = @_;


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

    $date //= `date -Idate`;

    # Тази заявка взима всички области към даден период
    my $req = $self->Request({
        f => 3, 
        date => $date, 
        hierarchy=> 5,
    }, !0)
        ->then(sub {
            my ($provinces) = @_;

            for my $row (@{ $provinces })
            {
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

    $date //= `date -Idate`;

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

        # $provinces = [$$provinces[$#{$provinces}]]; # DEBUG

        for my $province (@{ $provinces })
        {
            for my $href_key (keys %{ $$province{HREFS} })
            {
                if ($href_key == 'name')
                {
                    print STDERR "Get municipalities: ";
                    my $href = $$province{HREFS}{$href_key};
                    my $query_params = $self->ParseQueryParams( $self->ParseURI($href) );
                    
                    $$query_params{date} = $self->ParseDate( $date );

                    my $req = $self->Request($query_params, !0)
                        ->then(sub {
                                my ($table) = @_;

                                for my $row (@{ $table })
                                {
                                    $$row{TYPE} = "municipality";       
                                    $$row{PARENT} = $$province{ekatte_name};        
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

    $date //= `date -Idate`;

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
                    my $query_params = $self->ParseQueryParams( $self->ParseURI($href) );
                    
                    $$query_params{date} = $self->ParseDate( $date );

                    my $req = $self->Request($query_params, !0)
                        ->then(sub {
                                my ($table) = @_;

                                for my $row (@{ $table })
                                {
                                    $$row{TYPE} = "council";
                                    $$row{PARENT} = $$municipality{ekatte_name};
                                    print STDERR "Council $$row{name}\n";
                                    push @{ $councils }, $row;
                                }
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

    $date //= `date -Idate`;

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
                    print STDERR "Get settlements by ", (($by_council) ? "council" : "municipality"), ":\n";
                    my $href = $$parent{HREFS}{$href_key};
                    my $query_params = $self->ParseQueryParams( $self->ParseURI($href) );

                    $$query_params{hierarchy} = Q_PARAM_HIERARCHY_MUNICIPALITY if not $by_council;
                    $$query_params{date} = $self->ParseDate( $date );
                    
                    my $req = $self->Request($query_params, !0)
                        ->then(sub {
                                my ($table) = @_;

                                for my $row (@{ $table })
                                {
                                    for my $guess_type (qw{monastery village city})
                                    {
                                        if(defined $$row{$guess_type})
                                        {
                                            $$row{TYPE} = $guess_type;
                                            last;
                                        }
                                    }
                                                                                
                                    $$row{PARENT} = $$parent{ekatte_name};
                                    print STDERR "Settlement $$row{name}\n";    
                                    push @{ $settlements }, $row;
                                }
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

    $date =~ s/(\d{4})-(\d{2})-(\d{2})/$3.$2.DataManager/g;
    $date =~ s/^\s+|\s+$//g;

    return $date;
}


1;