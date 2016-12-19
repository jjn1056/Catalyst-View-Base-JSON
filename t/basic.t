use Test::Most;

{
  package MyApp::View::JSON;

  use Moo;
  extends 'Catalyst::View::Base::JSON';

  has [qw/name age api_version/] => (is=>'ro', required=>1);

  sub TO_JSON {
    my $self = shift;
    return +{
      name => $self->name,
      age => $self->age,
      api => $self->api_version,
    };
  }

  $INC{'MyApp/View/JSON.pm'} = __FILE__;

  package MyApp::Controller::Root;
  use base 'Catalyst::Controller';

  sub example :Local Args(0) {
    my ($self, $c) = @_;
    $->stash(age=>32);
    $c->view(name=>'John')->http_ok;
  }

  sub root :Chained('/') CaptureArgs(0) {
    my ($self, $c) = @_;
  }

  sub a :Chained(root) CaptureArgs(0) {
    my ($self, $c) = @_;
  }

  sub b :Chained(a) Args(0) {
    my ($self, $c) = @_;
  }

  $INC{'MyApp/Controller/Root.pm'} = __FILE__;

  package MyApp;
  
  use Catalyst;

  MyApp->config(
    default_view =>'JSON',
    'Controller::Root' => { namespace => '' },
    'View::JSON' => {
      returns_status => [200, 404],
      api_version => '1.1',
    },
  );

  MyApp->setup;
}

use Catalyst::Test 'MyApp';
use JSON::MaybeXS;

{
  ok my ($res, $c) = ctx_request( '/example' );
  is $res->code, 200;
  
  my %json = %{ decode_json $res->content };

  use Devel::Dwarn;
  Dwarn \%json;

#  is $json{a}, 1;
  # is $json{b}, 2;
  # is $json{c}, 3;
}

done_testing;
