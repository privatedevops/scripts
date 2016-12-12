#!/usr/bin/perl
package check_load;
use strict;
use warnings;
use base 'Exporter';
use Fcntl;
use Sys::Load qw/getload uptime/;
our @ISA        = qw(Exporter);
our @EXPORT = qw(loadavg);
our $VERSION    = 1.0;

my $alarm = '0';
my $mail_body = shift;
my $max_load = 7;
our $cur_load = (getload())[0];;

# executes at run-time, unless used as module
__PACKAGE__->loadavg() unless caller;


sub loadavg {
	$cur_load = (getload())[0];
	if ( $cur_load > $max_load ) {
		#print "Problem: $cur_load";
		system("killall -9 php httpd /usr/bin/php ");
		system("/usr/local/sbin/9");
		return 1;
	}
}

#print "$cur_load\n";
