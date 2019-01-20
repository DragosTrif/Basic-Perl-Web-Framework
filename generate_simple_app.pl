use strict;
use warnings;

use Getopt::Long;

use lib 'lib';
use SinglePageAplication;

my $app_name;

GetOptions( 'app_name=s' => \$app_name, )
  or die "Could not parse options";

die "please provide an app name\n" unless $app_name;

my $liteapp = SinglePageAplication->new( { name => $app_name } );

$liteapp->create_file_path();
$liteapp->generate_files();
