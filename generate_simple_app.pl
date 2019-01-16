use strict;
use warnings;

use lib 'lib';
use SinglePageAplication;

my $liteapp = SinglePageAplication->new({ name => 'test' });

$liteapp->create_file_path();
$liteapp->generate_files();