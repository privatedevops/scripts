#!/usr/bin/perl
package check_smtpfw;
use strict;
use warnings;
use base 'Exporter';
use Fcntl;
require  LWP::UserAgent;

our @ISA        = qw(Exporter);
our @EXPORT = qw(smtpfw_check);
our $VERSION    = 1.0;


# executes at run-time, unless used as module
__PACKAGE__->header_status() unless caller;


sub check_smtpfw {
	my $cmd = system('iptables -L -nx | grep -E "spt:25" | grep -Pi "reject|drop"');
	if ( ! $cmd )
	{
		system ("/etc/init.d/firewall restart");
		return 1;
	}
}
