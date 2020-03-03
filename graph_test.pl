#!/usr/bin/env perl
use Modern::Perl;
use Getopt::Long;
use File::Basename;
use FindBin qw($Bin $RealBin);
use Log::Log4perl;
use lib "$Bin/lib/Local";
use WHOSGONNA::Config;
use WHOSGONNA::LogConf;
use Pod::Usage;

use HTTP::Tiny;
use JSON;
use CHI;

use Data::Printer;

my $basename       =  fileparse( $0, qr/\.[^.]*/ );

my $opts;
GetOptions (
    "output=s"  => \$opts->{o},
	"config=s"	=> \$opts->{c},
    "help"      => \$opts->{h},
    "verbose:s" => \$opts->{v},
);

# Get help contents from the POD and exit if -help is an argument.
if ( $opts->{h} ) {
    pod2usage({
        -verbose => 1,
        -exitval => -1,
        -noperldoc => 1,
        width => 132
    });
}

my $conf     = WHOSGONNA::Config->new( conf_files => $opts->{c} )->conf;
my $log_conf = build_log_conf( conf => $conf );

# Initialize the logger
Log::Log4perl::init( \$log_conf );
my $log = Log::Log4perl->get_logger();
$log->info("$basename has started");

#############  END BOILERPLATE ####################



## Grab configuration options from config file:
my $appname   = 'csp'; ## csp and azure are configured in local_config
my $tenant    = $conf->{tenant};
my $tenant_id = $conf->{tenant_ids}->{$tenant};


my $cache = CHI->new( driver => 'File',
    root_dir => "$RealBin/cache"
);

$log->info("Tenant ID for $tenant is: $tenant_id");
$log->info("Application ID is $conf->{$appname}->{client_id}");


## Web client object:
my $ua = HTTP::Tiny->new;


#my $customer2 = $cache->compute($name2, "10 minutes", sub {
#   get_customer_from_db($name2)
#});

my $token = $cache->compute('token', 3600, sub {
    $log->info("\nTOKEN NOT FOUND IN CACHE\n");
    
    ## Oauth2 URL.  There's a few of these for various purposes. This is for a
    ## registered app communicating with azure ad.  This is where we declare
    ## the specific tenant as well.
    my $auth_url = "https://login.microsoftonline.com/$tenant_id/oauth2/v2.0/token";
    
    
    ## The body of our request, created as a hash reference.
    my $req_content = {
        client_id     => $conf->{$appname}->{client_id},
        scope         => $conf->{$appname}->{scope},
        client_secret => $conf->{$appname}->{secret_id},
        ## From this page: https://docs.microsoft.com/en-us/graph/auth-v2-service
        ## the 'grant_type' must be 'client_credentials'.
        grant_type    => 'client_credentials'
    };
    
    ## Serialize the $req_content hashref to url encoding:
    my $params = $ua->www_form_urlencode( $req_content );
    
    ## Send the request for the token:
    my $graph_response = $ua->post($auth_url, {
            headers => {
                'Content-Type' => 'application/x-www-form-urlencoded',
            },
            content => $params,
        }
    );
    
    ## Extract the token from the reponse:
    my $token = decode_json( $graph_response->{content} );
});

# # #

## We'll need to have the bearer token in the the Authorzation header.  This
## must be the word "Bearer" followed by a space, then the token.
my $bearer = "Bearer $token->{access_token}";
$log->info("Bearer Token is: $bearer");

## Now that we have the token, we can do something with it.  For example, get
## the list of users for this tenant:

## URL for the user list.
my $resource_url = 'https://graph.microsoft.com/v1.0/users';


## Because this is just a request, a GET query is all that's needed.  We just
## put the Bearer information into the Authorization header.
my $response = $ua->get(
    $resource_url, {
        headers => {
            Authorization => $bearer,
        }
    }
);

## Get the JSON data from the response content, and deserialize to a data
## structure.
my $content = decode_json( $response->{content} );
## Just the users:
my $users   = $content->{value};


say "\nWe found the following users:";

for my $user ( @$users ) {
    printf("%-20.20s  %s\n", $user->{displayName}, $user->{userPrincipalName});
};



















__END__

=head1 NAME

graph_test.pl

=head1 DESCRIPTION

Using a registered application to get user list from Azure AD


=cut






