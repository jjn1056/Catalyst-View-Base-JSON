use strict;
use warnings;

package Catalyst::View::Base::JSON;

use base 'Catalyst::View';
use Catalyst::Utils;
use HTTP::Status;
use Scalar::Util;

our $VERSION = 0.001;
our $CLASS_INFO = 'Catalyst::View::Base::JSON::_ClassInfo';

my $inject_http_status_helpers = sub {
  my ($class, $args) = @_;
  return unless $args->{returns_status};
  foreach my $helper( grep { $_=~/^http/i} @HTTP::Status::EXPORT_OK) {
    my $subname = lc $helper;
    my $code = HTTP::Status->$helper;
    my $codename = "http_".$code;
    if(grep { $code == $_ } @{ $args->{returns_status}||[]}) {
       eval "sub ${\$class}::${\$subname} { return shift->response(HTTP::Status::$helper,\@_) }";
       eval "sub ${\$class}::${\$codename} { return shift->response(HTTP::Status::$helper,\@_) }";
    }
  }
};

my @fields;
my $find_fields = sub {
  my $class = shift;
  for ($class->meta->get_all_attributes) {
    next unless $_->has_init_arg;
    push @fields, $_->init_arg;
  }
};

sub _build_class_info {
  my ($class, $args) = @_;
  Catalyst::Utils::ensure_class_loaded($CLASS_INFO);
  return $CLASS_INFO->new($args);
}

sub COMPONENT {
  my ($class, $app, $args) = @_;
  $args = $class->merge_config_hashes($class->config, $args);
  $class->$inject_http_status_helpers($args);
  $class->$find_fields;
  return bless [$class->_build_class_info($args)], $class;
}

my $get_stash_key = sub {
  my $self = shift;
  my $key = Scalar::Util::blessed($self) ?
    Scalar::Util::refaddr($self) :
      $self;
  return "__Pure_${key}";
};

my $prepare_args = sub {
  my ($self, @args) = @_;
  my %args = ();
  if(scalar(@args) % 2) { # odd args means first one is an object.
    my $proto = shift @args;
    foreach my $field (@fields) {
      if(my $cb = $proto->can($field)) { # match object methods to available fields
        $args{$field} = $proto->$field;
      }
    }
  }
  %args = (%args, @args);
  return $self->merge_config_hashes($self->config, \%args);
};

sub ACCEPT_CONTEXT {
  my ($self, $c, @args) = @_;
  die "View ${\$self->catalyst_component_name} can only be called with a context"
    unless Scalar::Util::blessed($c);

  my $stash_key = $self->$get_stash_key;
  $c->stash->{$stash_key} ||= do {
    my $args = $self->$prepare_args(@args);
    my $new = ref($self)->new(
      %{$args},
      %{$c->stash},
    );
    $new->{__class_info} = $self->[0];
    $new->{__ctx} = $c;
    $new;
  };
  return $c->stash->{$stash_key};    
}

sub ctx { return $_[0]->{__ctx} }
sub process { return shift->response(200, @_) }
sub detach { shift->ctx->detach(@_) }

my $class_info = sub { return $_[0]->{__class_info} };

sub response {
  my ($self, @proto) = @_;
  
  my $status = 200; 
  if( (ref \$proto[0] eq 'SCALAR') and
    Scalar::Util::looks_like_number($proto[0])
  ){
    $status = shift @proto;
  }
 
  my @headers = ();
  if(@proto) {
    @headers = @proto;
  }

  for($self->ctx->response) {
    $_->headers->push_header(@headers) if @headers;
    $_->status($status) unless $res->status != 200; # Catalyst default is 200...
    $_->content_type($self->$class_info->content_type) unless $res->content_type;

    unless($_->has_body) {
      my $json = $self->render;
      if(my $param = $self->$class_info->callback_param) {
        my $cb = $c->req->query_parameter($cbparam);
        $cb =~ /^[a-zA-Z0-9\.\_\[\]]+$/ || die "Invalid callback parameter $cb";
        $json = "$cb($json)";
      }
      $_->body($json);
    }
  }
}

sub render {
  my $self = shift;
  my $json = eval {
    $self->$class_info->json->encode($self);
  } || do {
    if(my $cb = $self->$class_info->handle_encode_error) {
      return $cb->($self, $@);
    } else {
      die $@;
    }
  };
  return $json;
}

sub uri {
  my ($self, $action_proto, @args) = @_;
  my $action = $action=~m/^\// ?
    $self->ctx->dispatcher->get_action_by_path($action_proto) :
      $self->ctx->controller->action_for($action_proto);
  return $self->ctx->uri_for($action, @args);
}

sub TO_JSON { die "View ${\$_[0]->catalyst_component_name} must define a 'TO_JSON' method!" }

1;

=head1 NAME


Catalyst::View::Base::JSON - a 'base' JSON View 

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 METHODS

This view defines the following methods

=head2 response

    $view->response($status, @headers, \%data||$object);
    $view->response($status, \%data||$object);
    $view->response(\%data||$object);
    $view->response($status);
    $view->response($status, @headers);

Used to setup a response.  Calling this method will setup an http status, finalize
headers and set a body response for the JSON.  Content type will be set to
'application/json' automatically (you don't need to set this in a header).

=head2 Method '->response' Helpers

We map status codes from L<HTTP::Status> into methods to make sending common
request types more simple and more descriptive.  The following are the same:

    $c->view->response(200, @args);
    $c->view->http_ok(@args);

    do { $c->view->response(200, @args); $c->detach };
    $c->view->http_ok(@args)->detach;

See L<HTTP::Status> for a full list of all the status code helpers.

=head2 render

Returns a string which is the JSON represenation of the current View.  Usually you
won't need to call this directly.

=head2 process

used as a target for $c->forward.  This is mostly here for compatibility with some
existing methodology.  For example allows using this View with the RenderView action
class (or L<Catalyst::Action::RenderView>).

=head1 ATTRIBUTES

This View defines the following attributes that can be set during configuration

=head1 SEE ALSO

L<Catalyst>, L<Catalyst::View>, L<Catalyst::View::JSON>,
L<JSON::MaybeXS>

=head1 AUTHOR
 
John Napiorkowski L<email:jjnapiork@cpan.org>
  
=head1 COPYRIGHT & LICENSE
 
Copyright 2016, John Napiorkowski L<email:jjnapiork@cpan.org>
 
This library is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
