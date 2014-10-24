package LCFG::Build::VCS::CVS;  # -*-cperl-*-
use strict;
use warnings;

# $Id: CVS.pm.in,v 1.4 2008/09/10 13:45:37 squinney Exp $
# $Source: /disk/cvs/dice/LCFG-Build-VCS/lib/LCFG/Build/VCS/CVS.pm.in,v $
# $Revision: 1.4 $
# $HeadURL$
# $Date: 2008/09/10 13:45:37 $

our $VERSION = '0.0.20';

use Moose;
with 'LCFG::Build::VCS';

use Cwd            ();
use File::Copy     ();
use File::Find     ();
use File::Path     ();
use File::Spec     ();
use IO::File qw(O_WRONLY O_CREAT O_NONBLOCK O_NOCTTY);

has '+binpath' => ( default => '/usr/bin/cvs' );

has 'root' => (
    is      => 'rw',
    isa     => 'Str',
    lazy    => 1,
    default => sub { _get_root(@_) },
);

has '+id' => ( default => 'CVS' );

# This should give a speed-up in loading

__PACKAGE__->meta->make_immutable;

sub _get_root {
    my ($self) = @_;

    my $root;

    my $rootfile = File::Spec->catfile( $self->workdir, 'CVS', 'Root' );
    if ( -f $rootfile ) {
        eval {
            my $fh = IO::File->new( $rootfile, 'r' );
            chomp( $root = $fh->getline );
            $fh->close;
        };
    }

    if ( !$root ) {
        $root = $ENV{CVSROOT};
    }

    return $root;
}

sub run_cmd {
    my ( $self, @args ) = @_;

    my @cmd = $self->_build_cmd(@args);

    if ( $self->dryrun ) {
        my $cmd = join q{ }, @cmd;
        print "Dry-run: $cmd\n";
    }
    else {
        system @cmd;
    }

    return ( $? != 0 ? 0 : 1 );
}

sub _build_cmd {
    my ( $self, @args ) = @_;

    my @cmd = ( $self->binpath, '-d', $self->root );
    if ( $self->quiet ) {
        push @cmd, '-Q';
    }
    push @cmd, @args;

    return @cmd;
}

sub genchangelog {
    my ($self) = @_;

    my $dir     = $self->workdir;
    my $logfile = $self->logfile;

    my $orig_dir = Cwd::abs_path();
    chdir $dir or die "gen: Could not access directory, $dir: $!\n";

    if ( !-e $logfile ) {

        # This bit borrowed from File::Touch
        sysopen my $fh, $logfile, O_WRONLY | O_CREAT | O_NONBLOCK | O_NOCTTY
            or die "Cannot create $logfile : $!\n";
        $fh->close or die "Cannot close $logfile : $!\n";

        # Assume it is not already part of the repository
        $self->run_cmd( 'add', $logfile );
    }

    my $cmd = '/usr/bin/cvs2cl --hide-filenames --accum --file ' . $logfile;

    if ( $self->quiet ) {
        $cmd .= ' --global-opts \'-Q\'';
    }

    # This requires a full shell to actually work, I think the cvs
    # command is the root cause.

    if ( $self->dryrun ) {
        print "Dry-run: $cmd\n";
    }
    else {
        system $cmd;
        if ( $? != 0 ) {
            die "Could not run cvs2cl: $!\n";
        }
    }

    chdir $orig_dir
        or die "Could not return to original directory, $orig_dir: $!\n";

    return;
}

sub checkcommitted {
    my ($self) = @_;

    my $orig_dir = Cwd::abs_path();

    my $dir = $self->workdir;
    chdir $dir or die "check: Could not access directory, $dir: $!\n";

    my @cmd = $self->_build_cmd('status');
    my $fh;
    open $fh, '-|', @cmd
        or die "Failed to run cvs status command: $!\n";

    my $line = <$fh>;
    if ( !defined $line ) {
        die "Failed to run cvs status command\n";
    }

    my @notcommitted;
    while ( defined $line ) {
        if ( $line =~ m/^File:\s+(\S+)/ ) {
            my $file = $1;
            if ( $line !~ m/Status:\s+Up-to-date/ ) {
                push @notcommitted, $file;
            }
        }
        $line = <$fh>;
    }

    close $fh;

    chdir $orig_dir
        or die "Could not return to original directory, $orig_dir: $!\n";

    my $allcommitted;
    if ( scalar @notcommitted > 0 ) {
        $allcommitted = 0;
    }
    else {
        $allcommitted = 1;
    }

    if (wantarray) {
        return ( $allcommitted, @notcommitted );
    }
    else {
        return $allcommitted;
    }
}

sub tagversion {
    my ( $self, $version ) = @_;

    $self->update_changelog($version);

    my $tag = $self->gen_tag($version);

    my $orig_dir = Cwd::abs_path();

    my $dir = $self->workdir;
    chdir $dir or die "tag: Could not access directory, $dir: $!\n";

    $self->run_cmd( 'commit', '-m', "Release: $version" )
        or die "Could not mark release for $dir at $version\n";

    $self->run_cmd( 'tag', '-F', '-c', $tag )
        or die "Could not tag $dir with $tag\n";

    $self->run_cmd( 'tag', '-F', '-c', 'latest' )
        or die "Could not tag $dir as latest\n";

    chdir $orig_dir
        or die "Could not return to original directory, $orig_dir: $!\n";

    return;
}

sub _process_cvs_entries {
    my ( $workdir, $entries ) = @_;

    my $path = $File::Find::name;

    if ( -f $path ) {
        my ( $vol, $dirname, $basename ) = File::Spec->splitpath($path);
        my @dirs = File::Spec->splitdir($dirname);

        # If the last element of the directory list is empty throw it away
        if ( length $dirs[-1] == 0 ) {
            pop @dirs;
        }

        if ( $dirs[-1] eq 'CVS' && $basename eq 'Entries' ) {
            pop @dirs; # remove the 'CVS' directory

            # This is a (hopefully) system-independent way of removing
            # the working directory from the front of the current
            # directory name to produce relative filenames.

            for ( my $i=0; $i<scalar(@{$workdir}); $i++) {
                if ( $dirs[0] eq $workdir->[$i] ) {
                    shift @dirs;
                }
                else {
                    last;
                }
            }

            my $dir = File::Spec->catdir(@dirs);

            my $fh = IO::File->new( $path, 'r' )
                or die "Could not open $path for reading: $!\n";
            while ( defined( my $entry = $fh->getline ) ) {

                if ( $entry =~ m{^/      # Line starts with a forward slash
                                 ([^/]+) # Stuff which is not a forward slash
                                 /       # Another forward slash
                                 \d      # Any digit (avoids deleted files)
                                }x ) {
                    push @{$entries}, [ $dir, $1 ];
                }
            }
            $fh->close;
        }
    }

    return;
}

sub export_devel {
    my ( $self, $version, $builddir ) = @_;

    my $workdir = $self->workdir;
    my $target = join q{-}, $self->module, $version;

    my $exportdir = File::Spec->catdir( $builddir, $target );

    if ( !$self->dryrun ) {
        File::Path::rmtree($exportdir);
        eval { File::Path::mkpath($exportdir) };
        if ($@) {
            die "Could not create $exportdir: $@\n";
        }
    }

    my @workdir = File::Spec->splitdir($workdir);
    # If the last element of the directory list is empty throw it away
    if ( length $workdir[-1] == 0 ) {
        pop @workdir;
    }

    my @entries;
    File::Find::find(
        {   wanted   => sub { _process_cvs_entries( \@workdir, \@entries ) },
            no_chdir => 1,
        },
        $workdir
    );

    for my $entry (@entries) {
        my ( $dirname, $fname ) = @{$entry};

        my $from_dir = File::Spec->catdir( $workdir, $dirname );
        my $to_dir   = File::Spec->catdir( $exportdir, $dirname );

        if ( !$self->dryrun && !-d $to_dir ) {
            eval { File::Path::mkpath($to_dir) };
            if ($@) {
                die "Could not create $to_dir: $@\n";
            }

            my ($dev,   $ino,     $mode, $nlink, $uid,
                $gid,   $rdev,    $size, $atime, $mtime,
                $ctime, $blksize, $blocks
            ) = stat $from_dir;

            chmod $mode, $to_dir or die "chmod on $to_dir failed: $!\n";
            chown $uid, $gid, $to_dir or die "chown on $to_dir failed: $!\n";

            # We don't care about atime/mtime for directories
        }

        my $from = File::Spec->catfile( $workdir, $dirname, $fname );
        my $to   = File::Spec->catfile( $exportdir, $dirname, $fname );

        my ($dev,   $ino,     $mode, $nlink, $uid,
            $gid,   $rdev,    $size, $atime, $mtime,
            $ctime, $blksize, $blocks
        ) = stat $from;

        if ( $self->dryrun ) {
            print "Dry-run: $from -> $to\n";
        }
        else {
            File::Copy::syscopy( $from, $to )
                or die "Copy $from to $to failed: $!\n";

            chmod $mode, $to or die "chmod on $to failed: $!\n";
            chown $uid, $gid, $to or die "chown on $to failed: $!\n";
            utime $atime, $mtime, $to or die "utime on $to failed: $!\n";

        }
    }

    return $exportdir;
}

sub export {
    my ( $self, $version, $builddir ) = @_;

    my $tag = $self->gen_tag($version);

    my $target = join q{-}, $self->module, $version;
    my $exportdir = File::Spec->catdir( $builddir, $target );

    if ( !$self->dryrun ) {
        if ( !-d $builddir ) {
            eval { File::Path::mkpath($builddir) };
            if ($@) {
                die "Could not create $builddir: $@\n";
            }
        }

        if ( -d $exportdir ) {
            File::Path::rmtree($exportdir);
        }
    }

    my $orig_dir = Cwd::abs_path();

    chdir $builddir
        or die "export: Could not access directory, $builddir: $!\n";

    $self->run_cmd( 'export', '-r', $tag, '-d', $target, $self->module );

    chdir $orig_dir
        or die "Could not return to original directory, $orig_dir: $!\n";

    return $exportdir;
}

sub checkout_project {
    my ( $self, $version, $outdir ) = @_;

    if ( !defined $outdir ) {
        $outdir = '.';
    }

    my $tag = $self->gen_tag($version);

    my $orig_dir = Cwd::abs_path();

    chdir $outdir or die "tag: Could not access directory, $outdir: $!\n";

    $self->run_cmd( 'checkout', '-r', $tag, $self->module );

    chdir $orig_dir
        or die "Could not return to original directory, $orig_dir: $!\n";

    return;
}

sub import_project {
    my ( $self, $version, $message ) = @_;

    my $vendor_tag  = $self->gen_tag();
    my $release_tag = $self->gen_tag($version);

    my $orig_dir = Cwd::abs_path();

    my $dir = $self->workdir;
    chdir $dir or die "tag: Could not access directory, $dir: $!\n";

    $self->run_cmd( 'import',
                    '-I', '!',
                    '-m', $message,
                    $self->module, $vendor_tag, $release_tag );

    chdir $orig_dir
        or die "Could not return to original directory, $orig_dir: $!\n";

    return;
}

no Moose;
1;
__END__

=head1 NAME

    LCFG::Build::VCS::CVS - LCFG build tools for CVS version-control

=head1 VERSION

    This documentation refers to LCFG::Build::VCS::CVS version 0.0.20

=head1 SYNOPSIS

    my $dir = ".";

    my $spec = LCFG::Build::PkgSpec->new_from_metafile("$dir/lcfg.yml");

    my $vcs = LCFG::Build::VCS::CVS->new( module  => $spec->fullname,
                                          workdir => $dir );

    $vcs->genchangelog();

    if ( $vcs->checkcommitted() ) {
      $vcs->tagversion();
    }

=head1 DESCRIPTION

This is part of a suite of tools designed to provide a standardised
interface to version-control systems so that the LCFG build tools can
deal with project version-control in a high-level abstract fashion.

This module implements the interface specified by
L<LCFG::Build::VCS>. It provides support for LCFG projects which use
the CVS version-control system. Facilities are available for
procedures such as importing and exporting projects, doing tagged
releases, generating the project changelog from the version-control
log and checking all changes are committed.

More information on the LCFG build tools is available from the website
http://www.lcfg.org/doc/buildtools/

=head1 ATTRIBUTES

=over 4

=item module

The name of the software package in this repository. This is required
and there is no default value.

=item workdir

The directory in which the CVS commands should be carried out. This is
required and if none is specified then it will default to '.', the
current working directory. This must be an absolute path but if you
pass in a relative path coercion will automatically occur based on the
current working directory.

=item binpath

The path to the CVS executable, by default this is /usr/bin/cvs. If
you want to alter this it must be set to an absolute path.

=item root

This is the CVS root. If not specified the module will attempt to
discover the right thing to use the first time you call the
accessor. It will look into the CVS/Root file in the working directory
for the project or if that fails use the CVSROOT environment variable.

=item quiet

This is a boolean value which controls the quietness of the CVS
commands. By default it is false and commands, such as CVS, will print
lots of extra stuff to the screen. If it is set to true the -Q option
will be passed to the CVS binary whenever a command is executed. The
cvs2cl(1) command used when automatically generating change log files
will also honour this option.

=item dryrun

This is a boolean value which controls whether the commands will
actually have a real effect or just print out what would be done. By
default it is false.

=item logname

The name of the logfile to which information should be directed when
doing version updates. This is also the name of the logfile to be used
if you utilise the automatic changelog generation option. The default
file name is 'ChangeLog'.

=back

=head1 SUBROUTINES/METHODS

=over 4

=item checkcommitted()

Test to see if there are any uncommitted files in the project
directory. Note this test does not spot files which have not been
added to the version-control system. In scalar context the subroutine
returns 1 if all files are committed and 0 (zero) otherwise. In list
context the subroutine will return this code along with a list of any
files which require committing.

=item genchangelog()

This method will generate a changelog (the name of which is controlled
by the logname attribute) from the log kept within the version-control
system. For CVS the cvs2cl(1) command is used.

=item tagversion($version)

This method is used to tag a set of files for a project at a
particular version. It will also update the changelog
appropriately. Tags are generated using the I<gen_tag()> method, see
below for details.

=item gen_tag($version)

Tags are generated from the name and version details passed in by
replacing any hyphens or dots with underscores and joining the two
fields with an underscore. For example, lcfg-foo and 1.0.1 would
become lcfg_foo_1_0_1.

=item run_cmd(@args)

A method used to handle the running of commands for the particular
version-control system. This is required for systems like CVS where
shell commands have to be executed. Not all modules will need to
implement this method as they may well use a proper Perl module API
(e.g. subversion).

=item export( $version, $builddir )

This will export a particular tagged version of the module. You need
to specify the target "build" directory into which the exported tree
will be put. The exported tree will be named like
"modulename-version". For example:

  my $vcs = LCFG::Build::VCS::CVS->new(module => "lcfg-foo");
  $vcs->export( "1.2.3", "/tmp" );

Would give you an exported tree of code for the lcfg-foo module tagged
as lcfg_foo_1_2_3 and it would be put into /tmp/lcfg-foo-1.2.3/

Returns the name of the directory into which the tree was exported.

=item export_devel( $version, $builddir )

This is similar to the export method. It takes the current working
tree for a module and exports it directly to another tree based in the
specified target "build" directory. This method copies over everything
except the special CVS directories. For example:

  my $vcs = LCFG::Build::VCS::CVS->new(module => "lcfg-foo");
  $vcs->export_devel( "1.2.3_dev", "/tmp" );

Would give you an exported tree of code for the lcfg-foo module
directory and it would be put into /tmp/lcfg-foo-1.2.3_dev/

Returns the name of the directory into which the tree was exported.

=item logfile()

This is a convenience method which returns the full path to the
logfile based on the workdir and logname attributes.

=back

=head1 DEPENDENCIES

This module is L<Moose> powered and it depends on
L<LCFG::Build::VCS>. You will need a working C<cvs> executable
somewhere on your system and a CVS repository for this module to be in
anyway useful.

=head1 SEE ALSO

L<LCFG::Build::PkgSpec>, L<LCFG::Build::VCS::None>, L<LCFG::Build::Tools>

=head1 PLATFORMS

This is the list of platforms on which we have tested this
software. We expect this software to work on any Unix-like platform
which is supported by Perl.

FedoraCore5, FedoraCore6, ScientificLinux5

=head1 BUGS AND LIMITATIONS

There are no known bugs in this application. Please report any
problems to bugs@lcfg.org, feedback and patches are also always very
welcome.

=head1 AUTHOR

    Stephen Quinney <squinney@inf.ed.ac.uk>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2008 University of Edinburgh. All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the terms of the GPL, version 2 or later.

=cut
