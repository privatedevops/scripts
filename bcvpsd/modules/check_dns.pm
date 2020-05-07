#!/usr/bin/perl
  
$ENV{'PATH'} = '/sbin:/usr/sbin:/bin:/usr/bin:/usr/local/sbin:/usr/local/bin';

package check_dns;

use strict;
use warnings;
use base 'Exporter';
use Fcntl;

our @ISA        = qw(Exporter);
#our @EXPORT = qw(dns);
our $VERSION    = 1.0;

__PACKAGE__->dns() unless caller;


use 5.010;
 
use Net::DNS ();

sub dns { 

	my $name_server = '127.0.0.1';
	my $hostname = 'mydomain.com';

	my $res = Net::DNS::Resolver->new(
		 timeout => 5,
		recurse => 1,
#		debug => 1,
	);
    $res->defnames(0);
    $res->retry(2);

	$res->nameservers($name_server);
	my $query = $res->search($hostname);

	my $result;
	if ($query) {
		foreach my $rr ($query->answer) {
			if ($rr->type eq "A") {
				$result = $rr->address;
				last;
			}
		}
	}
	if ($result) {
		print "DNS OK - $hostname resolved by DNS - $name_server, result: $result";
		return 0;
	} else {
		system("/usr/bin/systemctl restart named.service");
		return 1;
		print "$hostname is not resolving - $result";
	}
}
