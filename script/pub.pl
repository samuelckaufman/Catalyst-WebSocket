use strict;
use warnings FATAL => 'all';
use ZMQ::LibZMQ2;
use ZMQ::Constants qw( ZMQ_PUB ZMQ_SUBSCRIBE );
use SocialFlow::Log::Contextual qw[ :log :dlog ], -warn_like => 0;
use Try::Tiny;
use JSON::MaybeXS;
use Time::HiRes;
{
    package _Opt;

    use strict;
    use warnings FATAL => 'all';
    use Moo;
    use MooX::Options;

    option bind => ( is => 'ro', required => 1, format => 's' );
    option file => ( is => 'ro', required => 1, format => 's' );
    option sleep => ( is => 'ro', format => 's', default => .1 );

    1;
}

my $opt = _Opt->new_with_options;

sub _build_publisher {
    my $bind = shift;
    my $ctx = zmq_init() or die $!;
    my $publisher = zmq_socket( $ctx, ZMQ_PUB ) or die $!;
    my $h = "tcp://$bind";
#    if ( zmq_bind( $publisher, "tcp://127.0.0.1:9999" ) != 0 ) {
#        die $!;
    if ( zmq_bind( $publisher, $h ) != 0 ) {
        die "couldnt bind to $h: $!";
    }
    return $publisher;
}

my $pub = _build_publisher( $opt->bind );

open( my $fh, "<", $opt->file ) or die "couldnt open ${\ $opt->file }: $!";

while( 1 ) {
    while( defined( my $line = $fh->getline ) ) {
        if( zmq_send($pub, $line ) ) {
            die "died sending $line: $!";
        }
        Time::HiRes::sleep( $opt->sleep );
    }
    seek( $fh, 0, 0 );
}
