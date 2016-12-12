#!/usr/bin/perl

package brute_force;

use DBI;
use DBD::mysql;
use base 'Exporter';
use strict;
use warnings;
use Fcntl;
require  LWP::UserAgent;

our @ISA        = qw(Exporter);
our @EXPORT = qw(add_rules del_rules);
our $VERSION    = 1.0;

my $rule = shift;
my $line_ip = shift;

# CONFIG VARIABLEu
my $platform = "mysql";
my $database = "cphulkd";
my $host = "localhost";
my $port = "3306";
my $user = "cphulkd";

my $pass = `sed -e 's/^pass=//' -e '/client/d' -e '/^user=/d' -e 's/ //' -e 's/"//g' /var/cpanel/hulkd/password | perl -p -e 's/\n//'`;
#print $pass;

#DATA SOURCE NAME
my $dsn = "dbi:mysql:$database:localhost:3306";



### Prepare a SQL statement for execution
sub add_rules {
	# PERL DBI CONNECT
	my $dbh = DBI->connect($dsn, $user, $pass) or die "Unable to connect: $DBI::errstr\n";
#	my $sth = $dbh->prepare( "SELECT IP, NOTES from brutes UNION SELECT IP, ISPREFIX FROM blacklist" )
	my $sth = $dbh->prepare( "SELECT IP, NOTES from brutes UNION SELECT IP, ISPREFIX FROM blacklist UNION SELECT IP,USER FROM logins")
		or die "Can't prepare SQL statement: $DBI::errstr\n";
	$sth->execute();
	while (my $ref = $sth->fetchrow_hashref()) {
		my $add_ip = 1;
		our $IP = $ref->{'IP'};	
		our $NOTES = $ref->{'NOTES'};
		open (R_FIREWALL, '/etc/sysconfig/iptables-bgcode') || die("This file will not open!");
		while (<R_FIREWALL>) {
			my($line) = $_;
			chomp($line);
			next if /^\s*#/;
			#$line_ip =~ m/^([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])\.([01]?\d\d?|2[0-4]\d|25[0-5])$/;
	                my @line_ip=split /\s+/, $line;
			$line_ip = $line_ip[4];
#			print "=======  $line_ip ===== $IP\n";
			if ( $line_ip =~ m/$IP$/ ) {
				$add_ip=0
			}
		}
		if ( $add_ip == 1 ) {
			open (FIREWALL, '>>/etc/sysconfig/iptables-bgcode') || die("This file will not open!");
				print "Adding: $IP\n";
				print FIREWALL "iptables -I bruteforce-detect -s $IP -j DROP #$NOTES\n";
			close (FIREWALL);
			system("iptables -I bruteforce-detect -s $IP -j DROP");
			return 2;
		}
		close (R_FIREWALL);
	}
	$sth->finish();
	### Disconnect from the database
	$dbh->disconnect or warn "Error disconnecting: $DBI::errstr\n";
}

sub del_rules {
	open (R_FIREWALL, '/etc/sysconfig/iptables-bgcode') || die("This file will not open!");
	while (<R_FIREWALL>) {
		my $del_ip = 1;
		my($line) = $_;
		chomp($line);

		next if /^\s*#/;
	        if ( $line !~ m/bruteforce-detect/ ) {
        	    $del_ip = 0;
	            next;
        	}

		my @line_ip=split /\s+/, $line;
		my $line_ip = $line_ip[4];
		# PERL DBI CONNECT
		my $dbh = DBI->connect($dsn, $user, $pass) or die "Unable to connect: $DBI::errstr\n";
		my $sth = $dbh->prepare( "SELECT IP from brutes WHERE IP='$line_ip' UNION SELECT IP FROM blacklist WHERE IP='$line_ip' UNION SELECT IP FROM logins WHERE IP='$line_ip'")
			or die "Can't prepare SQL statement: $DBI::errstr\n";
		$sth->execute();
		while (my $ref = $sth->fetchrow_hashref()) {
			my $IP = $ref->{'IP'};
			if ( $IP =~ m/$line_ip/ ) {
				$del_ip=0;
			}
		}
	        $sth->finish();
        	### Disconnect from the database
	        $dbh->disconnect or warn "Error disconnecting: $DBI::errstr\n";
		if ( $del_ip == 1 ) {
			our $d_ip=$line_ip;
			print "Deleting: $line_ip\n";
			system("sed -i '/bruteforce-detect.*.$line_ip/d' /etc/sysconfig/iptables-bgcode");
#			my $mail_cmd = 'echo -en "IP '.$line_ip.' removed from DDoS firewall block list.\nFirewall reloaded." | mail -s "DDoS expired for: '.$line_ip.'" support@bgcode.com';
#			system ("$mail_cmd");
			system("iptables -D bruteforce-detect -s $d_ip -j DROP");
			return 3;
		}
	}
	close (R_FIREWALL);
}

add_rules();
#del_rules();
