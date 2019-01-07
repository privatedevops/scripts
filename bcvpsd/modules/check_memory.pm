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

our $freememory = (&freemem / 1024 /1024);

__PACKAGE__->memavg() unless caller;

sub memavg {
	if ( $freememory < 200 ) {
		print "Free mem is $freememory, restarting Nginx & PHP-FPM\n";
		system ("/usr/local/sbin/9");
		return 1;
	}
}
