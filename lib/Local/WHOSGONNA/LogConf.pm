package WHOSGONNA::LogConf;
use 5.008001;
use strict;
use warnings;
use FindBin qw($Bin $Script);
use File::Basename;
use File::Spec::Functions;
use Exporter 'import';

our $VERSION = "v0.0.1";

our @EXPORT    = 'build_log_conf';


sub build_log_conf {
    my %args    = @_;
    my $conf    = $args{conf};
    my $file    = $args{file};
    my $verbose = $args{verbose};

    
    my $basename =  fileparse( $0, qr/\.[^.]*/ );

    my $logdir   = $conf->{log}->{dir}  // "./";
    my $logname  = $conf->{log}->{name} // "$basename.log";

    my $logfile  = $file
                   // $conf->{log}->{file    }
                   // catfile($logdir, $logname );

    my $loglevel = $conf->{log}->{level}    // 'DEBUG';
    my $appender = $conf->{log}->{appender} // 'File';

    ## If file output is defined on the command line, override the appnder to
    ## use File.
    $appender    = 'File' if ( defined $file );

    my @logger_list = ($loglevel, 'LOG1');

    ## If verbose is defined, then add 'SCREEN' to the list of appenders:
    push (@logger_list, 'SCREEN') if ( defined $verbose );
    my $logger_list = join( ', ' ,  @logger_list );
    my $log_conf = qq(
        log4perl.rootLogger              = $logger_list
        log4perl.appender.LOG1           = Log::Log4perl::Appender::$appender
        log4perl.appender.LOG1.filename  = $logfile
        log4perl.appender.LOG1.mode      = append
        log4perl.appender.LOG1.layout    = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.LOG1.layout.ConversionPattern = %d{ISO8601} - %p %m %n
    );

    ## If verbose is defined, then use these details for the SCREEN appender.
    if (defined $verbose ) {
        my $level = $verbose || 'INFO';
        $log_conf .= qq(
        log4perl.appender.SCREEN           = Log::Log4perl::Appender::Screen
        log4perl.appender.SCREEN.Threshold = $level
        log4perl.appender.SCREEN.stderr    = 0
        log4perl.appender.SCREEN.layout    = Log::Log4perl::Layout::PatternLayout
        log4perl.appender.SCREEN.layout.ConversionPattern = %d{ISO8601} - %p %m %n
        );
    }

    return $log_conf;
}


1;




__END__

=encoding utf-8

=head1 NAME

WHOSGONNA::LogConf - Boilerplate for my Log4perl logging configuration

=head1 SYNOPSIS
    
    use Log::Log4perl;
    use WHOSGONNA::LogConf;
    
    # create the log config:    
    my $log_conf = build_log_conf({ 
        conf => $conf
    });
    
    # Initialize the logger
    Log::Log4perl::init( \$log_conf );
    my $log = Log::Log4perl->get_logger();

    # Now log something:
    $log->info("Logging has started");

Specify a file (and override the appender passed in conf).  This is
useful if you want to support a commandline argument to override the
the config file.

    # create the log config:
    my $log_conf = build_log_conf({
        conf => $conf,
        file => '/desired/log/file.log' 
    });


Or, pass C<verbose>, to push the output to the 'Screen' appender, 
B<in addition> to the appnder specificed in conf, or C<file>.

    # create the log config:
    my $log_conf = build_log_conf({
        conf    => $conf,
        verbose => '/desired/log/file.log'
    });


=head1 DESCRIPTION

WHOSGONNA::Config creates my desired logging configuration, with options
that can be set via config file easily.

=head1 FUNCTIONS

Really, there's only one function:  C<build_log_conf>, which returns a
config for Log::Log4perl.  So more intresting are the arguments for
C<build_log_conf>.

=over 4

=item conf => $conf

The C<conf> argument is the primary argument, which will contain the 
config parameters. I<Clearly a better explaination is needed here...>

=item file => '/path/to/desired/file.log'

Will write to the file listed here, overriding any appender and file
location set in C<conf>

=item verbose => 1

Will B<always> add an additional appender to write to the B<Screen>.


=back

=head1 LICENSE

Copyright (C) Ben Kaufman.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Ben Kaufman E<lt>ben.whosgonna.com@gmail.comE<gt>

=cut
