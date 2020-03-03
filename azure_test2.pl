#!/usr/bin/env perl
use Modern::Perl;
use Getopt::Long;
use File::Basename;
use FindBin qw($Bin);
use Log::Log4perl;
use lib "$Bin/lib/Local";
use WHOSGONNA::Config;
use WHOSGONNA::LogConf;
use Pod::Usage;

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



















__END__

=head1 NAME

$basename

=head1 DESCRIPTION

A desciption of the application.

=head1 SYNOPSIS

$basename -t <options>

=cut






