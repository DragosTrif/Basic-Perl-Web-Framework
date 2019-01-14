use strict;
use warnings;

my $liteapp =
  SinglePageAplication->new( { name => 'test' } );

$liteapp->create_file_path();
$liteapp->generate_files();

{
  use strict;
  use warnings;

  package SinglePageAplication;

  use Data::Dumper;
  use File::Path qw(make_path);
  use File::Spec;
  use Carp qw(croak carp);
  use Template::Tiny;
  use autodie;

  sub new {
    my ( $class, $arg_for ) = @_;
    my $self = bless {}, $class;
    $self->_initialize($arg_for);
    return $self;
  }

  sub _initialize {
    my ( $self, $arg_for ) = @_;
    my %arg_for = %$arg_for;

    my $class = ref $self;

    my $name        = delete $arg_for{name};

    unless ( defined $name ) {
      croak("$class requires a name and parent_name to be set");
    }

    $self->{name}                   = $name;
    $self->{file_path}              = $self->_generate_file_path_name();
    $self->{tt}                     = Template::Tiny->new( TRIM => 1, );
    $self->{class_names}->{app}     = $self->{name};
    $self->{class_names}->{modells} = 'DataHandler';
    $self->{class_names}->{controllers} = sprintf( "Render%s", $self->{name} );
    $self->{class_names}->{views} = 'main';
    $self->{class_names}->{base} = 'BaseRenderer';
  }

  sub generate_files {
    my $self = shift;

    my $file_name = $self->{class_names};
    #print Dumper($self->{file_path});
    #die;

    foreach my $path ( keys %{ $self->{file_path} } ) {
      my $exetension = 'pm';
      $exetension = 'tt'
        if $path eq 'views';
      my $file = File::Spec->catdir( $self->{file_path}->{$path},
        "$file_name->{$path}.$exetension" );

      print "$file\n";
      open( my $fh, '>', $file );
      print $fh $self->generate_class_code( class => $path );
      close $fh;

      # # this can a be a simple sub
      $self->_format_code_and_remove_bak_files( file => $file )
        if $path ne 'views';

    }

  }

  sub create_file_path {
    my $self = shift;

    my $config = $self->{file_path};

    foreach my $file_path ( keys %{$config} ) {
      print "Generating dir $config->{$file_path}\n";
      make_path( $config->{$file_path} )
        if !-d $config->{$file_path};
    }
  }

  sub _generate_file_path_name {
    my $self = shift;

    my $dir       = 'Controller';
    my $views_dir = 'Templates';
    my $app_name  = $self->{name};
    my $base_class_dir = 'Lib';

    my $config = {
      app     => File::Spec->catdir( $app_name, $dir),
      modells => File::Spec->catdir( $app_name, 'Modell' ),
      views => File::Spec->catdir( $app_name, $views_dir ),
      base => File::Spec->catdir( $app_name, $base_class_dir ),
    };

    

    # Do i realy need this name space?
    # $config->{controllers} = "$main_app/$dir/$app_name/controllers";
    return $config;
  }

  sub _get_method_code {
    my $self   = shift;
    my %params = (@_);

    my $render_main_method = <<'CODE';
  my $self = shift;
  my $params = shift;

  $self->_render_template(
    "main.tt",
    {
    }
  );
CODE

    my $say_hello = <<'CODE';
  my $self = shift;
  my %params = (@_);

  return "Hello $params{name}";
CODE

    my $render_say_hello = <<'CODE';
  my $self = shift;
  my $params = shift;

  $self->_render_template(
    "main.tt",
    {
      hello => $self->say_hello(),
    }
  );
CODE
    
    my $dispatch = <<'CODE';
  my $self = shift;
  my $params = shift;
  
  my $route = $params->{action} // 'render_main';
  
  $self->$route($params);
CODE
    my $render_template = <<'CODE';
  my $self = shift;
  my $file = shift;
  my $vars = shift;
  
  my $folder = $self->views();
  
  my $tt = Template->new({
    INCLUDE_PATH => "$folder",
    EVAL_PERL    => 1,
  }) || die $Template::ERROR, "\n";

  my $tempate_code = read_file("$folder/$file");
  
  $tt->process(\$tempate_code, $vars) // die $Template::ERROR;
  
CODE
    
    my $config = {
      render_main      => $render_main_method,
      say_hello        => $say_hello,
      render_say_hello => $render_say_hello,
      dispatch         => $dispatch,
      _render_template => $render_template,
    };

    return $config->{ $params{code} };
  }

  sub generate_class_code {
    my $self   = shift;
    my %params = (@_);

    my $class_config = {
      app => {
        class =>
          sprintf( '%s::%s', 'Controller', $self->{name} ),
        superclass      => 'BaseRenderer',
        superclass_path => 'lib1',
        modell          => $self->{class_names}->{modells},
        modell_path     => $self->{file_path}->{modells},
        attributes      => [
          {
            name    => '+views',
            default => sprintf( "'%s'", $self->{file_path}->{views} )
          },
          { name => 'DataHandler', default => 'DataHandler->new()' }
        ],
        methods => [
          {
            name => 'render_main',
            body => $self->_get_method_code( code => 'render_main' )
          },
          {
            name => 'render_say_hello',
            body => $self->_get_method_code( code => 'render_say_hello' ),
          }
        ]
      },
      modells => {
        class      => 'DataHandler',
        attributes => [
          {
            name    => 'dbh',
            default => ''
          }
        ],
        methods => [
          {
            name => 'say_hello',
            body => $self->_get_method_code( code => 'say_hello' )
          }
        ]
      },
      base => {
        class      => 'BaseRenderer',
        attributes => [
          {
            name    => 'views',
            default => sprintf("'%s'", 'test/Templates'),
          }
        ],
        methods => [
          {
            name => 'dispatch',
            body => $self->_get_method_code( code => 'dispatch' )
          },
          {
            name => '_render_template',
            body => $self->_get_method_code( code => '_render_template' )
          }
        ]
      }
    };

    my $output;
    my $input = $self->_get_class_template_input( class => $params{class} );
    $self->{tt}->process( \$input, $class_config->{ $params{class} }, $output );

    return $$output;
  }

  sub _get_class_template_input {
    my $self   = shift;
    my %params = (@_);

    my $app = <<"Class";
package [% class %];

use Moo;

use lib "[% superclass_path %]";
extends "[% superclass %]";

use lib "[% modell_path %]";
use [% modell %];

[% FOREACH a IN attributes %]
has [% a.name %] => (is => "ro", default => sub {[% a.default %]});
[% END %]

[% FOREACH m IN methods %]
sub [% m.name %] {
[% m.body %]
}
[% END %]

__PACKAGE__->meta->make_immutable;

1;
Class
    my $model_template = <<"TEMPLATE";
package [% class %];

use Moo;

[% FOREACH a IN attributes %]
has [% a.name %] => (is => "ro", default => sub {[% a.default %]});
[% END %]

[% FOREACH m IN methods %]
sub [% m.name %] {
[% m.body %]
}
[% END %]

__PACKAGE__->meta->make_immutable;

1;

TEMPLATE

    my $initial_form = <<TEMPLATE;
<form>
  <input type="text" name="name" value="Mickey">
  <input type="hidden" name="action" value="render_say_hello">
  <input type="submit" value="Submit">
<form>
TEMPLATE

    my $base_template = <<TEMPLATE;
    package [% class %];

use Moo;

use Template;
use File::Slurp 'read_file';

[% FOREACH a IN attributes %]
has [% a.name %] => (is => "ro", default => sub {[% a.default %]});
[% END %]

[% FOREACH m IN methods %]
sub [% m.name %] {
[% m.body %]
}
[% END %]

__PACKAGE__->meta->make_immutable;

1;
TEMPLATE
    
    my $config = {
      app     => $app,
      modells => $model_template,
      views   => $initial_form,
      base    => $base_template,
    };

    return $config->{ $params{class} };
  }

  sub _format_code_and_remove_bak_files {
    my $self   = shift;
    my %params = (@_);

    system( 'perltidy', '-i=2', '-b', $params{file} );
    system( 'rm', "$params{file}.bak" );
  }
  1;
}
