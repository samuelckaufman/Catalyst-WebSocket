package SocialFlow::StreamingWeb::Server;

use strict;
use warnings;

use Moo;
use MooX::Options;

use IO::Async::Loop;
use IO::Async::Timer::Periodic;
use IO::Async::Routine;
use IO::Async::Channel;
use IO::Async::Stream;

use Net::Async::WebSocket::Server;

use ZMQ::LibZMQ2;
use ZMQ::Constants qw( ZMQ_SUB ZMQ_SUBSCRIBE );

use JSON::MaybeXS;
use Devel::Dwarn;

use SocialFlow::Reporting::Daemon::ZMQSubscriber;

use curry;

my $json = JSON::MaybeXS->new;

$json->utf8(1);
has loop => ( is => 'lazy', );

has websocket_server => ( is => 'lazy', );

has zmq_subscriber => ( is => 'lazy',);

option port => (
    is => 'ro',
    format => 'i',
    default => 3000,
);

option zmq_host => (
    is => 'ro',
    format => 's',
    default => '127.0.0.1',
);

option zmq_port => (
    is => 'ro',
    format => 'i',
    default => 9999,
);

has clients => ( is => 'ro', default => sub { [] } );

has timer => (
    is      => 'lazy',
);

has data_channel => (
    is => 'ro',
    lazy => 1,
    default => sub { IO::Async::Channel->new },
);

sub _build_timer {
    my $self = shift;
    my $t = IO::Async::Timer::Periodic->new(
        interval => 1,
        on_tick  => $self->curry::weak::_on_tick
    );
    $self->loop->add( $t );
    return $t;
}
sub _build_loop { IO::Async::Loop->new };

sub _build_websocket_server {
    my $self = shift;
    my $server = Net::Async::WebSocket::Server->new(
        on_client => sub {
            my ( $ws_server, $client ) = @_;
            warn "on_client";
            $client->configure(
                on_frame => sub {
                    my ( $self, $frame ) = @_;
                    Dwarn $frame;
                },
            );
            push( $self->clients, $client );
        } );
    $self->loop->add( $server );
    return $server;
}

sub _build_zmq_subscriber {
    my $self = shift;
    my $zmq_port = $self->zmq_port;
    my $zmq_host = $self->zmq_host;
    my $channel = $self->data_channel;
    my $routine = IO::Async::Routine->new(
        channels_out => [ $channel ],
        code => sub {
            SocialFlow::Reporting::Daemon::ZMQSubscriber->new(
                port => $zmq_port,
                host => $zmq_host,
                callback => sub {
                    $channel->send( $_[0] );
                }
            )->run;
        } );
    return $routine;
}


my $i=1;
sub _on_tick {
    my $self = shift;
    warn "_on_tick";
#    for my $c ( @{ $self->clients } ) {
#        $c->send_frame(sprintf 'frame: #%s', $i++);
#    }
}

sub process {
    my( $self, $data ) = @_;
    my $str = $json->encode( $data );
    for my $c ( @{ $self->clients } ) {
        $c->send_frame($str);
    }
}
sub run {
    my $self = shift;
    $self->websocket_server->listen(
        service => $self->port,
        on_listen_error  => sub { die "Cannot listen - $_[-1]" },
        on_resolve_error => sub { die "Cannot resolve - $_[-1]" },
    );
    $self->timer->start;
    $self->loop->add( $self->zmq_subscriber );
    my $data_channel = $self->data_channel;
    my $process = $self->curry::weak::process;
    $data_channel->configure(
        on_recv => sub {
            my ( $channel, $data ) = @_;
            $process->( $data );
        }
    );
    $self->loop->loop_forever;
}

1;
