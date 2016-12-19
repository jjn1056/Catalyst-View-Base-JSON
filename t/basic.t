use Test::Most;

{
  package MyApp::View::Person;

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

  $INC{'MyApp/View/Person.pm'} = __FILE__;

  package MyApp::Controller::Root;
  use base 'Catalyst::Controller';

  sub example :Local Args(0) {
    my ($self, $c) = @_;
    $c->stash(age=>32);
    $c->view('Person', name=>'John')->http_ok;
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
    'Controller::Root' => { namespace => '' },
    'View::Person' => {
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
