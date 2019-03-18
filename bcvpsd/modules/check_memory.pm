#!/usr/bin/perl

$ENV{'PATH'} = '/sbin:/usr/sbin:/bin:/usr/bin:/usr/local/sbin:/usr/local/bin';

package check_memory;

use Sys::MemInfo qw(totalmem freemem totalswap);

use strict;
use warnings;
use base 'Exporter';
use Fcntl;

our @ISA        = qw(Exporter);
our @EXPORT = qw(memavg);
our $VERSION    = 1.0;

__PACKAGE__->memavg() unless caller;

sub memavg {
        my $freemem = (Sys::MemInfo::get("freemem") / 1024 / 1024 );

        our $freememory = sprintf "%.0f", $freemem;

        if ( $freememory < 2000 ) {
                print "Free mem is $freememory, restarting Nginx & PHP-FPM\n";
                system ("/usr/local/sbin/9");
                return 1;
        } else {
                return 0;
        }
}
