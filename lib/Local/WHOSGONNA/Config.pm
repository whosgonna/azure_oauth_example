package WHOSGONNA::Config;
use 5.008001;
use strict;
use warnings;
use Moo;
use Config::Any;
use Hash::Merge 'merge';
use FindBin qw($Bin $Script);
use File::Spec::Functions;
use File::Basename;

our $VERSION = "v0.0.3";



has 'etc_dirs' => (
    is => 'ro',
    required => 1,
    default => sub{
        return [
            '/etc',
            '/usr/local/etc'
        ];
    }
);

has _local_dir => (
    is => 'ro',
    default => sub {
        return $Bin
    },
);


has local_conf_prefix => (
    is => 'ro',
    default => 'local_'
);

has local_conf_suffix => (
    is => 'ro',
    default => '_local'
);

has additional_conf_stems => (
    is => 'ro'
);

has conf_files => (
    is => 'ro',
);

has home_dir => (
    is => 'ro',
    default => './',
);

has _basename => (
    is => 'lazy',
);

sub _build__basename {
    my $self = shift;
    my $fullname = catfile($Bin,$Script);
    my ($name,$path,$suffix) = fileparse($fullname, qr/\.[^.]*/ );
    return $name;
    #return {
    #    name   => $name,
    #    path   => $path,
    #    suffix => $suffix,
    #};
}

has conf_file_aliases => (
    is => 'ro',
    default => sub {
        return ( 
            [qw(
                conf
                config
                configure
                configuration
            )] 
        );
    }
);

has conf_stems => (
    is => 'lazy',
);

sub _build_conf_stems {
    my $self = shift;
    my $stems;
    my $basename   = $self->_basename;
    my $local_conf = $self->local_conf_prefix . $basename;
    my $conf_local  = $basename . $self->local_conf_suffix; 

    for my $etc_dir ( @{ $self->etc_dirs} ) {
        my $stem = catfile( $etc_dir, $basename );
        push @$stems, catfile( $etc_dir, $basename );
        push @$stems, catfile( $etc_dir, $local_conf );
        push @$stems, catfile( $etc_dir, $conf_local );
    }

    push @$stems, catfile( $ENV{HOME}, $basename );
    push @$stems, catfile( $ENV{HOME}, $local_conf );
    push @$stems, catfile( $ENV{HOME}, $conf_local );

    for my $alias ( @{ $self->conf_file_aliases } ) {
        push @$stems, catfile( $Bin, $alias );
        push @$stems, catfile( $Bin, ( $self->local_conf_prefix . $alias ) );
        push @$stems, catfile( $Bin, ( $alias . $self->local_conf_suffix ) );
    }

    return $stems;

}


has _conf_any => (
    is => 'lazy',
);

sub _build__conf_any {
    my $self = shift;
    
    my $conf_any = Config::Any->load_stems({ 
        stems => $self->conf_stems,
        use_ext => 1,
    });
    
    if ( $self->conf_files ){
        my $contents = Config::Any->load_files({
            files           => $self->conf_files,
            use_ext         => 1,
            flatten_to_hash => 1,
        });
        push ( @$conf_any, $contents );
    }
    

    return $conf_any;
}

sub make_config {
    my $args = shift;

    my $conf = WHOSGONNA::Config->new( $args );

}


has conf => (
    is => 'lazy',
);

sub _build_conf {
    my $self = shift;
    my $conf;

    for my $individual_conf ( @{ $self->_conf_any } ) {
        my ($filename, $sections) = %$individual_conf;
        $conf = merge( $sections, $conf);
    }
    return $conf;
}



sub inherit_order {
    my $self = shift;
    my @file_list;
    for my $files ( @{ $self->_conf_any } ) {
        push @file_list, (keys %$files);
    }
    return @file_list;
}

1;




__END__

=encoding utf-8

=head1 NAME

WHOSGONNA::Config - Gather config files from locations where I (WHOSGONNA) 
would expect to find them.  Config files can be any format handled by 
L<Config::Any>.

=head1 SYNOPSIS

Assuming a perl script of: /path/to/my_project/my_script.pl

In C</etc/my_script.yaml> are system wide configurations for the script:

    foo: bar
    system: variable


In C</path/to/my_project/config.yaml>, general configuration for the script. 
Any values defined here will override the values from C</etc/my_script.yaml>.
Thus, the value for C<foo> becomes C<baz>. If you're using git, this file is in 
the same directory as the script, so it would get tracked automatically.

    foo: baz
    fruit:
        - apple
        - banana
        - orange
    hashref:
        summer: warm
        winter: cold
    credentials:
        - user: whosgonna


In C</path/to/my_project/local_config.yaml> are stored values that will override
the values from C</path/to/my_project/config.yaml>.  Hashes and Lists will
merge using the behavior from C<Hash::Merge>.   The intention for the 
C<local_config.*> file is that it can be added to C<.gitignore> so that it is
safe for data that may be undesireable to store in a remote git repository.

    credentials:
        user: ben
        password:  Secret


In C<~/my_project/my_script.pl> the C<conf> method is used at instantiation to
return a single hashref of all merged values:

    use WHOSGONNA::Config;
    use Data::Dumper;  
    
    my $conf = WHOSGONNA::Config->new->conf;
    print Dumper $conf;


This results in:

    $VAR1 = {
              'hashref' => {
                             'winter' => 'cold',
                             'summer' => 'warm'
                           },
              'credentials' => {
                                 'password' => 'Secret',
                                 'user' => 'ben'
                               },
              'foo' => 'bar',
              'system' => 'variable',
              'fruit' => [
                           'apple',
                           'banana',
                           'orange'
                         ]
            };



=head1 DESCRIPTION

WHOSGONNA::Config will pull together C<Config::Any> compatable files from 
common locations and merge them all into a single hashref.


=head1 Order of File Inclusion

Assuming script ~/scripts/myscript.pl (and yaml files), any of the files listed
will be included in the resulting configuration with values in files further
down the list superseding those in earlier files, meaning that if C<name: ben> 
is set in C</etc/myscript.yaml>, and C<name: whosgonna> is set in 
C<$Bin/conf.yaml>, that C<whosgonna> will overwirte C<ben>.

=over 4

=item 1

/etc/myscript.yaml

=item 2

/etc/local_myscript.yaml

=item 3

/etc/myscript_local.yaml

=item 4

/usr/local/etc/myscript.yaml

=item 5

/usr/local/etc/local_myscript.yaml

=item 6

/usr/local/etc/myscript_local.yaml

=item 7

~/myscript.yaml

=item 8

~/local_myscript.yaml

=item 9

~/myscript_local.yaml

=item 10

~/myproject/conf.yaml

=item 11

~/myproject/local_conf.yaml

=item 12

~/myproject/conf_local.yaml

=item 13

/usr/home/ben/projects/WHOSGONNA-Config/xt/config.yaml

=item 14

/usr/home/ben/projects/WHOSGONNA-Config/xt/local_config.yaml

=item 15

/usr/home/ben/projects/WHOSGONNA-Config/xt/config_local.yaml

=item 16

/usr/home/ben/projects/WHOSGONNA-Config/xt/configure.yaml

=item 17

/usr/home/ben/projects/WHOSGONNA-Config/xt/local_configure.yaml

=item 18

/usr/home/ben/projects/WHOSGONNA-Config/xt/configure_local.yaml

=item 19

/usr/home/ben/projects/WHOSGONNA-Config/xt/configuration.yaml

=item 20

/usr/home/ben/projects/WHOSGONNA-Config/xt/local_configuration.yaml

=item 21

/usr/home/ben/projects/WHOSGONNA-Config/xt/configuration_local.yaml


=back

=head1 LICENSE

Copyright (C) Ben Kaufman.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Ben Kaufman E<lt>ben.whosgonna.com@gmail.comE<gt>

=cut

