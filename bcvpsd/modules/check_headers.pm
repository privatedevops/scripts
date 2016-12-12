#!/usr/bin/perl
package check_headers;
use strict;
use warnings;
use base 'Exporter';
use Fcntl;
require  LWP::UserAgent;

our @ISA        = qw(Exporter);
our @EXPORT = qw(header_status);
our $VERSION    = 1.0;


# executes at run-time, unless used as module
__PACKAGE__->header_status() unless caller;


sub header_status {
#	my @urls = ('http://www.bgcode.com/',  'http://www.uzdp.bg/bg');
	my @urls = ('http://www.shop2bg.com');

	my $ua = LWP::UserAgent->new;
	for my $url (@urls)
	{
		print $url;
	    $ua->agent('BGCODE Ltd. web status checker');
		my $response = $ua->get($url);
		$ua->timeout(30);
		$ua->env_proxy;
		$ua->max_redirect(0);
		if ($response->is_success) {
			print " - \n".$response->status_line;
			next ;
		} else {
			system("/usr/local/sbin/9");
			return 1;
		            die $response->status_line;
		}
	}
}
