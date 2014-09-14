use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/lib";

use SocialFlow::StreamingWeb;
use Plack::Builder;

builder {
    enable "Plack::Middleware::Static",
        path => qr{^/(static)/},
        root => "$FindBin::Bin/root";
        SocialFlow::StreamingWeb->apply_default_middlewares(SocialFlow::StreamingWeb->psgi_app);
        SocialFlow::StreamingWeb->psgi_app;
};

# vim: set et fenc=utf-8 ff=unix ft=perl sts=0 sw=4 ts=4 :
