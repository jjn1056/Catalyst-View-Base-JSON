package Catalyst::View::Base::JSON::_ClassInfo;

use Moo;

our $DEFAULT_JSON_CLASS = 'JSON::MaybeXS';
our $DEFAULT_CONTENT_TYPE = 'application/json';
our %JSON_INIT_ARGS = (
  utf8 => 1,
  convert_blessed => 1);

has json => (
  is=>'ro',
  required=>1,
  init_arg=>undef,
  lazy=>1,
  default=>sub {
    my $self = shift;
    eval "use ${\$self->json_class}; 1" ||
      die "Can't use ${\$self->json_class}, $@";

    return $self->json_class->new(
      $self->json_init_args);
  });

has content_type => (
  is=>'ro',
  required=>1,
  default=>$DEFAULT_CONTENT_TYPE);

has returns_status => (
  is=>'ro',
  predicate=>'has_returns_status');

sub HANDLE_ENCODE_ERROR {
  my ($view, $err) = @_;
  return $view->http_internal_server_error({ error => "$err"})->detach;
}

has handle_encode_error => (
  is=>'ro',
  required=>1,
  default=>\&HANDLE_ENCODE_ERROR);

has json_class => (
  is=>'ro',
  require=>1,
  default=>sub {
    return $DEFAULT_JSON_CLASS;
  });

has json_init_args => (
  is=>'ro',
  required=>1,
  lazy=>1,
  default=>sub {
    my $self = shift;
    my %init = (%JSON_INIT_ARGS, $self->has_json_extra_init_args ?
      %{$self->json_extra_init_args} : ());

    return \%init;
  });

has json_extra_init_args => (
  is=>'ro',
  predicate=>'has_json_extra_init_args');

has callback_param => ( is=>'ro', predicate=>'has_callback_param');

1;

=head1 NAME

Catalyst::View::Base::JSON::_ClassInfo - Application Level Info for your View 

=head1 SYNOPSIS

    NA - Internal use only.

=head1 DESCRIPTION

This is used by the main class L<Catalyst::View::JSON::PerRequest> to hold
application level information, mostly configuration and a few computations you
would rather do once.

No real public reusably bits here, just for your inspection.

=head1 ATTRIBUTES

This View defines the following attributes that can be set during configuration

=head2 content_type

Sets the response content type.  Defaults to 'application/json'.

=head2 returns_status

An optional arrayref of L<HTTP::Status> codes that the view is allowed to generate.
Setting this will injection helper methods into your view:

    $view->http_ok;
    $view->202;

Both 'friendly' names and numeric codes are generated (I recommend you stick with one
style or the other in a project to avoid confusion.  Helper methods return the view
object to make common chained calls easier:

    $view->http_bad_request->detach;

=head2 callback_param

Optional.  If set, we use this to get a method name for JSONP from the query parameters.

For example if 'callback_param' is 'callback' and the request is:

    localhost/foo/bar?callback=mymethod

Then the JSON response will be wrapped in a function call similar to:

    mymethod({
      'foo': 'bar',
      'baz': 'bin});

Which is a common technique for overcoming some cross-domain restrictions of
XMLHttpRequest.

There are some restrictions to the value of the callback method, for security.
For more see: L<http://ajaxian.com/archives/jsonp-json-with-padding>

=head2 json_class

The class used to perform JSON encoding.  Default is L<JSON::MaybeXS>

=head2 json_init_args

Arguments used to initialize the L</json_class>.  Defaults to:

    our %JSON_INIT_ARGS = (
      utf8 => 1,
      convert_blessed => 1);

=head2 json_extra_init_args

Allows you to 'tack on' some arguments to the JSON initialization without
messing with the defaults.  Unless you really need to override the defaults
this is the method you should use.

=head2 handle_encode_error

A reference to a subroutine that is called when there is a failure to encode
the data given into a JSON format.  This can be used globally as an attribute
on the defined configuration for the view, and you can set it or overide the
global settings on a context basis.

Setting this optional attribute will capture and handle error conditions.  We
will NOT bubble the error up to the global L<Catalyst> error handling (we don't
set $c->error for example).  If you want that you need to set it yourself in
a custom handler, or don't define one.

The subroutine receives two arguments: the view object and the exception. You
must setup a new, valid response.  For example:

    package MyApp::View::JSON;

    use Moo;
    extends 'Catalyst::View::Base::JSON';

    package MyApp;

    use Catalyst;

    MyApp->config(
      default_view =>'JSON',
      'View::JSON' => {
        handle_encode_error => sub {
          my ($view, $err) = @_;
          $view->http_bad_request({ err => "$err"})->detach;
        },
      },
    );

    MyApp->setup;

Or setup/override per context:

    sub error :Local Args(0) {
      my ($self, $c) = @_;

      $c->view->set_handle_encode_error(sub {
          my ($view, $err) = @_;
          $view->http_bad_request({ err => "$err"})->detach
        });

      $c->view->http_ok( $bad_data );
    }

B<NOTE> If you mess up the return value (you return something that can't be
encoded) a second exception will occur which will NOT be handled and will then
bubble up to the main application.

B<NOTE> We define a rational default for this to get you started:

    sub HANDLE_ENCODE_ERROR {
      my ($view, $err) = @_;
      $view->http_internal_server_error({ error => "$err"})->detach;
    }

=head1 UTF-8 NOTES

Generally a view should not do any encoding since the core L<Catalyst>
framework handles all this for you.  However, historically the popular
Catalyst JSON views and related ecosystem (such as L<Catalyst::Action::REST>)
have done UTF8 encoding and as a result for compatibility core Catalyst code
will assume a response content type of 'application/json' is already UTF8 
encoded.  So even though this is a new module, we will continue to maintain this
historical situation for compatibility reasons.  As a result the UTF8 encoding
flags will be enabled and expect the contents of $c->res->body to be encoded
as expected.  If you set your own JSON class for encoding, or set your own
initialization arguments, please keep in mind this expectation.

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::View>, L<Catalyst::View::JSON>,
L<JSON::MaybeXS>

=head1 AUTHOR
 
See L<Catalyst::View::Base::JSON>

=head1 COPYRIGHT & LICENSE
 
See L<Catalyst::View::Base::JSON>

=cut
