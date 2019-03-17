#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use FindBin ();
use Test::LongString;

use MySQL::Workbench::DBIC;

my $bin             = $FindBin::Bin;
my $file            = $bin . '/test.mwb';
my $namespace       = 'MyApp::DB';
my $load_namespaces = ['Test', 'Virtual', 'Core::Result'];
my $output_path     = $bin . '/Test' . $$;

my $foo = MySQL::Workbench::DBIC->new(
    file                     => $file,
    output_path              => $output_path,
    namespace                => $namespace,
    result_namespace         => 'Core',
    load_result_namespace    => $load_namespaces,
    load_resultset_namespace => $load_namespaces,
);

isa_ok( $foo, 'MySQL::Workbench::DBIC', 'object is type M::W::D' );

if( -e $output_path ){
    rmtree( $output_path );
}

$foo->create_schema;

(my $path = $namespace) =~ s!::!/!;

my $subpath = $output_path . '/' . $path;
ok( -e $subpath , 'Path ' . $subpath . ' created' );
ok( -e $subpath . '/DBIC_Schema.pm', 'Schema' );
ok( -e $subpath . '/DBIC_Schema/Core/Result/Gefa_User.pm', 'Gefa_User' );
ok( -e $subpath . '/DBIC_Schema/Core/Result/UserRole.pm', 'UserRole' );
ok( -e $subpath . '/DBIC_Schema/Core/Result/Role.pm', 'Role' );

my $content = do{ local (@ARGV, $/) = $subpath . '/DBIC_Schema/Core/Result/UserRole.pm'; <> };
like_string $content, qr/sqlt_deploy_hook/;

like_string $content,
    qr/add_index\( \s*
        type \s*   => \s* "normal", \s*
        name \s*   => \s* "fk_Gefa_User_has_Role_Role1_idx", \s*
        fields \s* => \s* \['RoleID'\]
    /xms;

my $schema_content = do{ local (@ARGV, $/) = $subpath . '/DBIC_Schema.pm'; <> };
#diag $schema_content;
like_string $schema_content, qr/result_namespace => \['Test', 'Virtual', 'Core::Result'\],/, 'load_namespace set';
like_string $schema_content, qr/resultset_namespace => \['Test', 'Virtual', 'Core::Result'\],/, 'load_namespace set';

done_testing();

sub rmtree{
    my ($path) = @_;
    opendir my $dir, $path or die $!;
    while( my $entry = readdir $dir ){
        next if $entry =~ /^\.?\.$/;
        my $file = File::Spec->catfile( $path, $entry );
        if( -d $file ){
            rmtree( $file );
            rmdir $file;
        }
        else{
            unlink $file;
        }
    }
    closedir $dir;
}
