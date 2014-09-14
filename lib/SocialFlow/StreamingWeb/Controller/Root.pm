package SocialFlow::StreamingWeb::Controller::Root;

use strict;
use warnings;

use Moose;
use MooseX::MungeHas;

extends 'Catalyst::Controller';

use Net::Async::WebSocket::Server;
use Protocol::WebSocket::Handshake::Server;
use SocialFlow::Log::Contextual qw[ :log :dlog ];
use Devel::Dwarn;
has ws_server => ( is => 'lazy',);

has loop => ( is => 'rw' );


sub _build_ws_server {
    my $self = shift;
    log_info { "_build_ws_server" };
    my $server = Net::Async::WebSocket::Server->new(
        on_accept => sub { "on_accept"; },
        on_client => sub {
            my(undef,$client) = @_;
            log_info { "on_client" };
            $client->configure(
                on_frame => sub {
                    my( $self, $frame ) = @_;
                    Dlog_info { "frame received: $_" } $frame;
                },
            );
        },
        on_handshake => sub {
            my ( $self, $client, $hs, $continuation ) = @_;
            warn "on_handshake";
          $continuation->( $hs->req->origin eq "http://localhost" );
      }
    )
}

__PACKAGE__->config({
        action => {
            base => {
                CaptureArgs => 0,
                Chained => "/",
                PathPart => "",
            },
            base_index => {
                Chained => "base",
                Args => 0,
                PathPart => "",
            },
#            ws2 => {
#                Chained => "base",
#                PathPart => 'ws',
#                Args => 0,
#            },
        }
    });


sub base {
    my($self,$c) = @_;
    my $loop = $c->req->env->{'io.async.loop'};
    unless( $self->loop ) {
        warn "adding $loop";
        $self->loop( $loop );
        $self->loop->add( $self->ws_server );
    }
}

sub base_index {
    my($self,$c) = @_;
    Dlog_info { "req env: $_"} $c->req->env;
    log_info { 'hello' };
    my $url = $c->uri_for_action($self->action_for('ws'));
    $url->scheme('ws');
    $c->stash(websocket_url => $url);
    log_info { "websocket_url: $_[0]" } $url;
    my $async_server_req = $c->req->env->{"net.async.http.server.req"};
    my $io = $async_server_req->stream;
    warn $io;
    $io->autoflush( 1 );
    $io->write("WHATS UP!");
#    $c->res->body("WHAT UP");
#    $c->res->status(200);
#    warn "BASE_INDEX IS DONESKI";
}

my @state;

#sub ws2 {
#    my( $self, $c ) = @_;
#    my $async_server_req = $c->req->env->{"net.async.http.server.req"};
##    my $io = $async_server_req->stream;
#    my $server = Net::Async::WebSocket::Server->new(
#        handle => $c->req->io_fh,
#        on_accept => sub { "on_accept"; },
#        on_client => sub {
#            my(undef,$client) = @_;
#            log_info { "on_client" };
#            $client->configure(
#                on_frame => sub {
#                    my( $self, $frame ) = @_;
#                    Dlog_info { "frame received: $_" } $frame;
#                },
#            );
#        },
#        on_handshake => sub {
#            my ( $self, $client, $hs, $continuation ) = @_;
#            warn "on_handshake";
#          $continuation->( $hs->req->origin eq "http://localhost" );
#      }
#    )
#    $self->ws_server->listen( handle => $c->req->io_fh );
#    warn "after listen";
#}
#sub ws {
#    my( $self, $c ) = @_;
#    my $async_server = $c->req->env->{"net.async.http.server"};
#    my $async_server_req = $c->req->env->{"net.async.http.server.req"};
#    my $io = $async_server_req->stream;
#    Dlog_info { "env: $_"} $c->req->env;
#    push( @state, $io );
#    my $hs = Protocol::WebSocket::Handshake::Server
#          ->new_from_psgi($c->req->env);
#    $io->configure(
#      on_read => sub {
#        my ($stream, $buff, $eof) = @_;
#        if( $hs->is_done ) {
#            log_info { "Handshake is done!!!!" };
##            (my $frame = $hs->build_frame)->append($$buff);
#            my $framebuffer = $hs->build_frame;
#            $framebuffer->append( $$buff ); # modifies $$buffref
#            $framebuffer->append( "FLOOPS DE WHOOPS");
#            $stream->write( $framebuffer->to_bytes);
##            $stream->write($hs->build_frame(buffer => "Echo Initiated")->to_bytes);
#            Dlog_info { "now buff is $_" } $buff;
##            warn $frame;
#           while( defined( my $frame = $framebuffer->next ) ) {
#               warn $frame;
#           }
##            while( 1 ) {
##                warn "sigh";
##                $stream->write($hs->build_frame(buffer=> "After handshake is done, heres some data")->to_bytes);
##                sleep 1;
##            }
##                while( my $message = $frame->next ) {
##                warn "FRAME!";
##                return 0;
##            }
#        } else {
#          $hs->parse($$buff);
#          $stream->write($hs->to_string);
#          $stream->write($hs->build_frame(buffer => "Echo Initiated")->to_bytes);
#
#        }
#    });
##    Dlog_info { "env: $_"} $c->req->env;
##    Dlog_info { "async_server_req: $_"} $async_server_req;
##    log_info { "ws request received"};
##    my $fh = $io->write_handle;
##    $io->set_handle( undef );
##    my $server = $self->ws_server;
##    $server->add_child(Net::Async::WebSocket::Protocol->new( handle => $fh));
##    $io->configure(
##      on_read => sub {
##        my ($stream, $buff, $oef) = @_;
##        if($hs->is_done) {
##          (my $frame = $hs->build_frame)->append($$buff);
##          while (my $message = $frame->next) {
##            $message = $hs->build_frame(buffer => $message)->to_bytes;
##            $stream->write($message);
##          }
##          return 0;
##        } else {
##          $hs->parse($$buff);
##          $stream->write($hs->to_string);
##          $stream->write($hs->build_frame(buffer => "Echo Initiated")->to_bytes); 
##        }
##      }
##    );
#}

__PACKAGE__->meta->make_immutable;
__END__
1;
    $io->configure(
        on_read => sub {
            my ( $stream, $buff, $oef ) = @_;
            if ( $hs->is_done ) {
                ( my $frame = $hs->build_frame )->append($$buff);
                while ( my $message = $frame->next ) {
                    my $decoded = decode_json $message;
                    if ( my $user = $decoded->{new} ) {
                        $decoded = { username => $user, message => "Joined!" };
                        foreach my $item ( $self->history ) {
                            $stream->write(
                                $hs->build_frame(
                                    buffer => encode_json($item)
                                )->to_bytes
                            );
                        }
                    }
                    $self->add_to_history($decoded);
                    foreach my $client ( $self->clients ) {
                        $client->write(
                            $hs->build_frame( buffer => encode_json($decoded) )
                              ->to_bytes );
                    }
                }
                return 0;
            }
            else {
                $hs->parse($$buff);
                $stream->write( $hs->to_string );

            }
        } );

There is no previous '{' to match a '}' on line 31
31: }
    ^
}
31:	final indentation level: 0
31:	To save a full .LOG file rerun with -g
