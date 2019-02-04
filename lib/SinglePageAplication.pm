use strict;
use warnings;

package SinglePageAplication;

use File::Path qw(make_path);
use File::Spec;
use Carp qw(croak carp);
use Template::Tiny;
use File::Slurp 'read_file';
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

  my $name = delete $arg_for{name};

  unless ( defined $name ) {
    croak("$class requires a name and parent_name to be set");
  }

  $self->{name}                   = $name;
  $self->{file_path}              = $self->_generate_file_path_name();
  $self->{tt}                     = Template::Tiny->new( TRIM => 1, );
  $self->{class_names}->{app}     = $self->{name};
  $self->{class_names}->{modells} = 'DataHandler';
  $self->{class_names}->{controllers} = sprintf( "Render%s", $self->{name} );
  $self->{class_names}->{views}       = 'main';
  $self->{class_names}->{base}        = 'BaseRenderer';
  $self->{class_names}->{psgi}        = 'app';
  $self->{class_names}->{utils}       = 'Utils';
  $self->{ConfigTemplates}            = 'ConfigTemplates';
}

sub generate_files {
  my $self = shift;

  my $file_name = $self->{class_names};

  foreach my $path ( keys %{ $self->{file_path} } ) {
    my $exetension = 'pm';

    $exetension = 'tt'
      if $path eq 'views';

    $exetension = 'psgi'
      if $path eq 'psgi';

    my $file = File::Spec->catdir( $self->{file_path}->{$path},
      "$file_name->{$path}.$exetension" );

    
    open( my $fh, '>', $file );
    print $fh $self->generate_class_code( class => $path );
    close $fh;

    # this can a be a simple sub
    $self->_format_code_and_remove_bak_files( file => $file )
      if $path ne 'views';

  }

}

sub create_file_path {
  my $self = shift;

  my $config = $self->{file_path};

  foreach my $file_path ( keys %{$config} ) {
    print "Generating dir $config->{$file_path}\n"
      if $file_path ne 'utils';
   
    make_path( $config->{$file_path} )
      if !-d $config->{$file_path};
  }
}

sub _generate_file_path_name {
  my $self = shift;

  my $dir            = 'Controller';
  my $views_dir      = 'Templates';
  my $app_name       = $self->{name};
  my $base_class_dir = 'Lib';

  
  my $config = {
    app     => File::Spec->catdir( $app_name, $dir ),
    modells => File::Spec->catdir( $app_name, 'Modell' ),
    views   => File::Spec->catdir( $app_name, $views_dir ),
    base    => File::Spec->catdir( $app_name, $base_class_dir ),
    utils   => File::Spec->catdir( $app_name, $base_class_dir ),
    psgi    => $self->{name},
  };

  return $config;
}

sub _get_method_code {
  my $self   = shift;
  my %params = (@_);

  my $config = {
    render_main =>
      File::Spec->catdir( 'lib', $self->{ConfigTemplates}, 'render_main.tt' ),
    say_hello =>
      File::Spec->catdir( 'lib', $self->{ConfigTemplates}, 'say_hello.tt' ),
    render_say_hello => File::Spec->catdir(
      'lib', $self->{ConfigTemplates},
      'render_say_hello.tt'
    ),
    dispatch =>
      File::Spec->catdir( 'lib', $self->{ConfigTemplates}, 'dispatch.tt' ),
    _render_template => File::Spec->catdir(
      'lib', $self->{ConfigTemplates},
      'render_template.tt'
    ),
    mount => File::Spec->catdir( 'lib', $self->{ConfigTemplates}, 'mount.tt' ),
    _respond_as_josn => File::Spec->catdir(
      'lib', $self->{ConfigTemplates},
      '_respond_as_josn.tt'
    ),
    give_me_json =>
      File::Spec->catdir( 'lib', $self->{ConfigTemplates}, 'give_me_json.tt' ),
    load_params =>
      File::Spec->catdir( 'lib', $self->{ConfigTemplates}, 'load_params.tt' ),
    response =>
      File::Spec->catdir( 'lib', $self->{ConfigTemplates}, 'response.tt' ),
    load_plugins =>
      File::Spec->catdir( 'lib', $self->{ConfigTemplates}, 'load_plugins.tt' ),
  };

  my $code = read_file( $config->{ $params{code} } );

  return $code;
}

sub generate_class_code {
  my $self   = shift;
  my %params = (@_);
  
  my $class_config = {
    app => {
      class      => $self->{name},
      superclass => 'BaseRenderer',
      modell     => $self->{class_names}->{modells},
      attributes => [
        {
          name    => '+views',
          default => sprintf( "'%s'", 'Templates' ),
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
        },
        {
          name => 'give_me_json',
          body => $self->_get_method_code( code => 'give_me_json' ),
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
          default => sprintf( "'%s'", 'test/Templates' ),
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
        },
        {
          name => '_respond_as_josn',
          body => $self->_get_method_code( code => '_respond_as_josn' )
        },
      ]
    },
    psgi => {

      #class      => 'BaseRenderer',
      controller_path => $self->{class_names}->{app},
      methods         => [
        {
          body => $self->_get_method_code( code => 'mount' )
        }
      ],
    },
    utils => {
      methods => [
        {
          name => 'load_params',
          body => $self->_get_method_code( code => 'load_params' )
        },
        {
          name => 'response',
          body => $self->_get_method_code( code => 'response' )
        },
        {
          name => 'load_plugins',
          body => $self->_get_method_code( code => 'load_plugins' )
        },
      ],
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
  
  my $config = {
    app =>
      File::Spec->catdir( 'lib', $self->{ConfigTemplates}, 'controller.tt' ),
    modells =>
      File::Spec->catdir( 'lib', $self->{ConfigTemplates}, 'model.tt' ),
    views => File::Spec->catdir( 'lib', $self->{ConfigTemplates}, 'html.tt' ),
    base  => File::Spec->catdir( 'lib', $self->{ConfigTemplates}, 'base.tt' ),
    psgi  => File::Spec->catdir( 'lib', $self->{ConfigTemplates}, 'app.tt' ),
    utils => File::Spec->catdir( 'lib', $self->{ConfigTemplates}, 'utils.tt' ),
  };

  return read_file( $config->{ $params{class} } );
}

sub _format_code_and_remove_bak_files {
  my $self   = shift;
  my %params = (@_);

  system( 'perltidy', '-i=2', '-b', $params{file} );
  system( 'rm', "$params{file}.bak" );
}

1;
