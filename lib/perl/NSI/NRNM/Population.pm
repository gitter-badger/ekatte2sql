package NSI::NRNM::Population;

use utf8;
use strict;
use Data::Dumper;


use AnyEvent::HTTP;
use AnyEvent::Promises qw(deferred merge_promises);


use lib ('.');
use NSI::NRNM::Interface;


use base 'NSI::NRNM::Interface';


sub new {
    my ($class, $options) = @_;

    $$options{table_header} = [qw(number name ekatte_name)];

    my $self = $class->SUPER::new($options);

    return $self;
}


sub GetPopulation($$)
{
    my ($self, $ekatte) = @_;


    $self->Request({
        ezik => "bul",
        f => 9,
        search => $ekatte,
    }, !0)
        ->then(sub {
            my ($cities) = @_;

            $self->GetPopulationBySearchResults($cities);
        });
}

sub GetPopulationBySearchResults($$)
{
    my ($self, $search_result) = @_;
    my @requests;
    my $result = {};

    die('Search result not an array') unless ref $search_result eq 'ARRAY';


    for my $city (@{ $search_result })
    {
        for my $href_key (keys $$city{HREFS})
        {
            if ($href_key eq 'name')
            {
                my $req = $self->Request($$city{HREFS}{$href_key}, [qw{date population name}])
                    ->then(sub {
                        my ($table) = @_;

                        $$result{$$city{ekatte_name}} = $self->ParsePopulationByYear($table);
                    });
                push @requests, $req;
            }
        }
    }


    return merge_promises( @requests )
        ->then(sub {
            return $result;
        });
}

sub ParsePopulationByYear($$)
{
    my ($self, $table) = @_;
    my $result = {};

    for my $row (@{ $table })
    {
        my $date = $$row{date};
        $date =~ s/(\d{2}).(\d{2}).(\d{4})/$3-$2-$1/;
        $$result{ $date } = $row;
    }                        
        
    return $result;
}

1;