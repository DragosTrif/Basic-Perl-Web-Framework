#!/usr/bin/env perl
use strict;
use warnings;

use Data::Dumper;
use Test::More tests => 2;
use Test::Differences;
use Test::MockObject;

use lib 'lib';

use_ok('SinglePageAplication');
my $mock = Test::MockObject->new();

$mock->fake_module(
  'SinglePageAplication' => (
    create_file_path => sub { return 1 },
    generate_files   => sub {
      my $self      = shift;
      my $file_name = $self->{class_names};
      my $result    = {};

      foreach my $path ( keys %{ $self->{file_path} } ) {
        my $extension = $self->_set_file_extension( extension => $path );

        my $file = File::Spec->catdir( $self->{file_path}->{$path},
          "$file_name->{$path}.$extension" );

        $result->{$path} = $self->generate_class_code( class => $path )
          if $extension eq 'pm' || $extension eq 'psgi';
      }
      return $result;
    },
  )
);

my $liteapp = SinglePageAplication->new( { name => 'test5' } );

my $got = $liteapp->generate_files();
my $expected = {
  'app' => 'package test5;

use Moo;

use lib "Lib";
extends "BaseRenderer";

use lib "Modell";
use DataHandler;

has +views => (is => "ro", default => sub {\'Templates\'});has DataHandler => (is => "ro", default => sub {DataHandler->new()});

sub render_main {
my $self = shift;
my $params = shift;

$self->_render_template(
  "main.tt",
  {
  }
);
}sub render_say_hello {
my $self = shift;
my $params = shift;

$self->_render_template(
  "main.tt",
  {
    hello => $self->DataHandler()->say_hello(name => $params->{name}),
  }
);
}sub give_me_json {
my $self = shift;


  $self->_respond_as_json({ 
    name      => \'Dragos\',
    last_name => \'Trif\',
  });
}

__PACKAGE__->meta->make_immutable;

1;',
  'base' => 'package BaseRenderer;

use Moo;

use Template;
use File::Slurp \'read_file\';
use JSON;

has views => (is => "ro", default => sub {\'test/Templates\'});

sub dispatch {
my $self = shift;
my $params = shift;

my $route = $params->{action} // \'render_main\';

$self->$route($params);
}sub _render_template {
my $self = shift;
my $file = shift;
my $vars = shift;

my $folder = $self->views();
my $output;

my $tt = Template->new({
  INCLUDE_PATH => "$folder",
  EVAL_PERL    => 1,
  PRE_PROCESS  => [ \'static/layout/index.html\' ],
  POST_PROCESS => [ \'static/layout/footer.html\'] 
}) || die $Template::ERROR, "\\n";

my $tempate_code = read_file("$folder/$file");

$tt->process(\\$tempate_code, $vars, \\$output) // die $Template::ERROR;

return $output;
}sub _respond_as_json {

  my $self = shift;
  my $perl_data = shift;

  my $json = JSON->new();

  return  $json->pretty->encode( $perl_data );
}

__PACKAGE__->meta->make_immutable;

1;',
  'utils' => 'package Utils;

use Exporter::NoWork;
use HTML::Entities \'encode_entities\';

sub load_params {

  my $request = shift;

  my %params;

  foreach my $param ( sort $request->param() ) {
    $params{ encode_entities($param) } =
      encode_entities( $request->param($param) );
  }

  return \\%params;

}sub response {

  my %params = @_;

  my $request = $params{request};
  my $content = $params{content};
  my $type    = $params{content_type};

  my $response = $request->new_response(200);

  $response->content_type($type);
  $response->content($content);
  return $response->finalize;

}sub load_plugins {

  
  my $plugins = {
    AUTHORIZATION => sub {
       "Auth::Basic", authenticator => sub {
        my ( $username, $password ) = @_;

        return $username eq \'Dragos\' && $password eq \'Trif\';
      };
    },
  };

  return $plugins;

}

1;',
  'modells' => 'package DataHandler;

use Moo;

has dbh => (is => "ro", default => sub {});

sub say_hello {
my $self = shift;
my %params = (@_);

return "Hello $params{name}";
}

__PACKAGE__->meta->make_immutable;

1;',
  'psgi' => 'use strict;
use warnings;

use Plack::Builder;
use Plack::Request;
use Plack::Session;
use Plack::App::File;

use lib (\'Controller\', \'Lib\');
use Utils qw(load_params response load_plugins);

use test5;

my $plugins = load_plugins(); 

my $apps = {
  test5
   => sub {
    my $env     = shift;
    my $request = Plack::Request->new($env);
    my $session = Plack::Session->new($env);

    my $params     = load_params($request);
    my $controller = test5->new();
    my $content    = $controller->dispatch($params);

    return response(
      request      => $request,
      content      => $content,
      content_type => \'text/html\',
    );

  },
};


builder {
mount "/js"  => Plack::App::File->new(file  => \'./Templates/static/js/script.js\');
  mount "/css" => Plack::App::File->new(file  => \'./Templates/static/css/style.css\');
  
 mount \'/\' => builder {
    enable $plugins->{AUTHORIZATION}->();
    $apps->{test5}; 
  };
};'
};


eq_or_diff( $got, $expected, 'generated perl code is ok' );
