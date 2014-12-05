package NSI::Interface;

use utf8;
use strict;
use Data::Dumper;


use URI;
use Mojo::DOM;
use LWP::Simple;


use AnyEvent::HTTP;
use AnyEvent::Promises qw(deferred merge_promises);


use constant {
    EKATTE_URL => "http://www.nsi.bg/nrnm/index.php",
};



sub new {
    my ($class, $options) = @_;
    
    $options = {} if ref $options ne "HASH";

    my %base = (
        EKATTE_URL => EKATTE_URL,
        smart_cols => [qw(name)],
        unit_types => [
            { type => "monastery", text => "ман." },
            { type => "village", text => "с."},
            { type => "city", text => "гр."},
            { type => "municipality", text => "общ."},
            { type => "province", text => "обл."},
        ],

        %{ $options }

        );


    my $self = \%base;

    bless $self, $class;

    return $self;
}


sub GetTableFromHtml($$)
{
    my ($self, $html) = @_;
    
    # parse html to perl object    
    my $dom = Mojo::DOM->new($html);
    my $result = $dom->at('.restitle');

    # find nearest table
    while(1)
    {
        $result = $result->next;
        last if (defined $result) && ($result->type eq "table");
    }

    return $result;
}


sub ParseTable($$)
{
    my ($self, $html) = @_;
    my $result = $self->GetTableFromHtml($html);
    my $table = [];


    my $row_index;
    for my $row ($result->find('tr')->each)   
    {
        # skip rows if needed
        next if ((defined $$self{skip_rows}) && ($row_index++ < $$self{skip_rows}));

        my $table_row = [];


        my $cell_index;
        for my $cell ($row->find('td')->each)
        {
            # skip cols if needed
            next if ((defined $$self{skip_cols}) && ($cell_index++ < $$self{skip_cols}));

            if (defined $cell->children('a'))
            {
                print 2;
            }


            push @{ $table_row }, $cell->all_text; 
        }


        push @{ $table }, $table_row;
    }


    return $table;
}


sub ParseTableToHash($$)
{
    my ($self, $html) = @_;
    my $result = $self->GetTableFromHtml($html);
    my $table = [];
    my $table_header = [qw(number ekatte_name name)];

    my $row_index;
    for my $row ($result->find('tr')->each)   
    {
        # skip rows if needed
        next if ((defined $$self{skip_rows}) && ($row_index++ < $$self{skip_rows}));

        my $table_row = {};


        my $cell_index;
        for my $cell ($row->find('td')->each)
        {
            # skip cols if needed
            next if (($cell_index++ < $$self{skip_cols}) && (defined $$self{skip_cols}));

            my $table_header_col = $$table_header[$cell_index - $$self{skip_cols} - 1];


            $$table_row{$table_header_col} = $cell->all_text;


            if ($cell->at('a') ne "")
            {
                $$table_row{HREFS}{$table_header_col} = $cell->children('a')->attr("href")->join->to_string;
            }


            if ($self->IsSmartCol($table_header_col))
            {
                my $parsed_result = $self->ParseSmartCol($$table_row{$table_header_col});

                $table_row = { %{ $table_row }, %{ $parsed_result } }
            }
        }


        push @{ $table }, $table_row;
    }


    return $table;
}


sub IsSmartCol($$)
{
    my ($self, $col_name) = @_;

    if (ref $$self{smart_cols} eq "HASH")
    {
        return $$self{smart_cols}{$col_name};
    }
    elsif (ref $$self{smart_cols} eq "ARRAY")
    {
        return $col_name ~~ $$self{smart_cols};
    }
    else
    {
        return $col_name eq $$self{smart_cols};
    }

    return 0;
}


sub ParseSmartCol($$)
{
    my ($self, $content) = @_;
    my $types = $$self{unit_types};
    my $result = {};

    my @units = split ',', $content;

    for my $unit (@units)
    {
        $unit =~ s/^\s+|\s+$//g;
        

        # for my $unitss (@units){}
        for my $type (@{ $types })
        {
            my $match = quotemeta $$type{text};

            if($unit =~ /^$match/i)
            {
                $unit =~ s/^$match//g;
                $$result{$$type{type}} = $unit;
            }
        }
    }
    
    return $result;
}


sub RequestEKATTE($$)
{
    my ($self, $params) = @_;
    my $url = $self->BuildURL($params);
    my $d = deferred;

    http_get $url => sub {
        my ( $body, $headers ) = @_;
        return ($headers->{Status} >= 200 && $headers->{Status} < 300)
            ? $d->resolve( $body )
            : $d->reject('receiving data failed with status: '.  $headers->{Status} );
    };

    return $d->promise;
}


sub RequestEKATTE($$)
{
    my ($self, $params, $hash_parse) = @_;
    my $req = $self->wget($params);

    $req->then(sub {
            my ($html) = @_;
            my $table;

            if ($hash_parse)
            {
                $table = $self->ParseTable($html);
            }
            else
            {
                $table = $self->ParseTableToHash($html);
            }
            

            return $table;
        });

    return $req;
}

sub BuildURL($$)
{
    my ($self, $params) = @_;
    my $url = URI->new( $$self{EKATTE_URL} );    

    if(ref $params eq "HASH" || ref $params eq "ARRAY")
    {
        $url->query_form(%{ $params });
    }
    else
    {
        $url .= "?$params";
    }


    return $url;
}

sub ParseURI($$)
{
    my ($self, $uri) = @_;

    $uri =~ s/.*\?(.*)/$1/g;
    
    return $uri;
}

sub ParseQueryParams($$)
{
    my ($self, $uri) = @_;
    my $query_params = {};

    $uri =~ s/.*\?(.*)/$1/g;
    my @query_string = split '&', $uri;

    for my $query_string_param (@query_string)
    {
        my @key_value = split '=', $query_string_param;

        $$query_params{$key_value[0]} = $key_value[1];
    }

    return $query_params;
}

1;