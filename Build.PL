use 5.006;
use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Hash::Storage::Driver::DBI',
    license             => 'perl',
    dist_author         => q{Viktor Turskyi <koorchik@cpan.org>},
    dist_version_from   => 'lib/Hash/Storage/Driver/DBI.pm',
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        'perl'         => 5.010,
	'Hash-Storage' => 0,
	'DBI'          => 0,
    },
    add_to_cleanup      => [ 'Hash-Storage-Driver-DBI-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
