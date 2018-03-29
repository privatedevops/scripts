#!/usr/bin/perl
package check_headers;
use strict;
use warnings;
use feature 'say';

use HTTP::Tiny;

use base 'Exporter';
use Fcntl;

our @ISA        = qw(Exporter);
our @EXPORT = qw(header_status);
our $VERSION    = 1.0;

our $url = shift;
our $urlissue   = $url;

# executes at run-time, unless used as module
__PACKAGE__->header_status() unless caller;


sub header_status {
        my $Client = HTTP::Tiny->new();

        my @urls = (
                'https://www.bgcode.com/bg/',
                'https://hostingidol101.com',
        );

        for my $url (@urls) {
                my $response = $Client->get($url);
                my $http_status = HTTP::Tiny->new(max_redirect => 0)->get("$url")->{status};
                if ( $http_status != 200) {
#                       print "problem";
			system("/usr/local/sbin/9");
                        return 1;
                }
#               } else {
#                       print print "$url - $http_status\n";
#               }
        }
}
