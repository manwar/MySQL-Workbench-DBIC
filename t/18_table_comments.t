#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use FindBin ();
use Test::LongString;

BEGIN {
	use_ok( 'MySQL::Workbench::DBIC' );
}

use MySQL::Workbench::DBIC::FakeDBIC;

my $bin         = $FindBin::Bin;
my $file        = $bin . '/comment.mwb';
my $namespace   = 'MyApp::DB';
my $output_path = $bin . '/Test' . $$;

my $foo = MySQL::Workbench::DBIC->new(
    file           => $file,
    namespace      => $namespace,
    output_path    => $output_path,
    column_details => 1,
    table_comments => 1,
);
isa_ok( $foo, 'MySQL::Workbench::DBIC', 'object is type F::D::D' );

if( -e $output_path ){
    rmtree( $output_path );
}

$foo->create_schema;

(my $path = $namespace) =~ s!::!/!;

my $subpath = $output_path . '/' . $path;
my $role_class = $subpath . '/DBIC_Schema/Result/Test.pm';

ok -e $role_class;

my $check = q~__PACKAGE__->add_columns\\(
    test_id => \\{
        data_type          => 'INT',
        is_auto_increment  => 1,
        is_numeric         => 1,
        retrieve_on_insert => 1,
    \\},
    passphrase => \\{
        data_type          => 'VARCHAR',
        is_nullable        => 1,
        size               => 45,
        'passphrase' => 'rfc2307',
        'passphrase_args' => \\{
          'algorithm' => 'SHA-1',
          'salt_random' => '?20'?
        \\},
        'passphrase_check_method' => 'check_passphrase',
        'passphrase_class' => 'SaltedDigest'
    \\},
    another_phrase => \\{ # A comment in JSON
        data_type          => 'VARCHAR',
        is_nullable        => 1,
        size               => 45,
    \\},

\\);~;

my $content = do{ local (@ARGV, $/) = $role_class; <> };
like $content, qr/$check/;
like $content, qr/__PACKAGE__->load_components\([^\)]+PassphraseColumn/;
like $content, qr/another_phrase => \{ # A comment in JSON/;
like $content, qr/=head1 \s+ DESCRIPTION \s+ A \s+ table \s+ comment \s+ in \s+ JSON/x;

my $comment_table = do { local (@ARGV, $/) = $subpath . '/DBIC_Schema/Result/another_comment.pm'; <> };
like $comment_table, qr/=head1 \s+ DESCRIPTION \s+ In \s+ this \s+ table/x;
like $comment_table, qr/comment_id => \{ # A column comment/;
like $comment_table, qr/comment_text => \{ # A multiline\n\s{22}# comment/;

eval{
    rmtree( $output_path );
    rmdir $output_path;
};

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

