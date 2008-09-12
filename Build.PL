use strict;
use warnings;
use Module::Build;

my $build = Module::Build->new(
    module_name   => 'LCFG::Build::VCS',
    dist_abstract => 'LCFG version control infrastructure',
    dist_author   => 'Stephen Quinney <squinney@inf.ed.ac.uk>',
    dist_version  => '0.0.21',
    license => 'gpl',
    requires => {
        'perl'         => '5.6.1',
        'Moose'        => '0.57',
        'Date::Format' => '1.16',
        'File::Copy::Recursive' => '0.36',
    },
    build_requires => { 'Test::More' => 0 },
    create_makefile_pl => 'traditional',
    add_to_cleanup => [ 'LCFG-Build-VCS-*', 'MANIFEST.bak', 'Changes.bak' ],
);
$build->create_build_script;
