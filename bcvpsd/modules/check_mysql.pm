#!/usr/bin/perl
package check_mysql;
use strict;
use warnings;
use base 'Exporter';
use Fcntl;
use Tie::File;
our @ISA        = qw(Exporter);
our @EXPORT = qw(broken_db mysql_check);
our $VERSION    = 1.0;

my $alarm = '0';
my $mail_body = shift;

# executes at run-time, unless used as module
__PACKAGE__->main() unless caller;

sub get_my_pass {
	my $mysql_pass = '';
	open FILE, '<', '/root/.my.cnf' or logger("Failed to open /root/.my.cnf for reading: $!") and die;
	while (<FILE>) {
		if ($_ =~ /^password\=\"(.*)\"$/) {
			$mysql_pass = $1;
			last;
		} elsif ($_ =~ /^password\=(.*)$/) {
			$mysql_pass = $1;
			last;
		}
	}
	close FILE;
	logger("Failed to get the mysql pass from /root/.my.cnf") if ($mysql_pass eq '') and die;
	return $mysql_pass;
}

sub broken_db {
	my $length  = 25;
	my $file = "/var/lib/mysql/mysql.err";
	tie(my @file, "Tie::File", $file, autochomp => 0) or die("ack - $!");	
	my $mlog = ("@file[$#file - $length +0 ..  $#file]");
	if ( $mlog =~ m/ERROR/i ) {
		return 1; # 1 - found broken dbs ili ERROR v loga na mysqla
		exit(1);
#	} else {
#		return 0; #nqma problemi
	}
}
sub main {
	my $self = shift;
	sub logger { print @_, "\n"; }
	my $status = $self->mysql_check(1, 1);
	logger("\nMySQL status: $status");
}

sub mysql_check {
	my $body = shift;
	my $debug = shift;
	my $mysql_pass = get_my_pass();
	my $check_results = eval {
		use POSIX ':signal_h';
		use DBD::mysql;
		local $SIG{ALRM} = sub { die "alarm\n"; 
	};
	alarm(1);

	my $mask = POSIX::SigSet->new( SIGALRM ); # signals to mask in the handler
	my $action = POSIX::SigAction->new(sub { die "alarm\n" }, $mask);
	my $oldaction = POSIX::SigAction->new();

	# Connection check starts here
	my $dbh = ();
	if ($dbh = DBI->connect("DBI:mysql:host=localhost","root","$mysql_pass")) {
		print "Initial connection to the SQL OK";
	} else {
		print "Failed to connect on localhost root.";
		$alarm = 1;
		return 1;
	}
	# Qeury check starts here
	eval {
		alarm(1); # local alarm for the sql connection itself
		#if ($dbh->do('show status LIKE "%Uptime%"')) {
		if ($dbh->do('select User from mysql.user limit 1')) {
			alarm(0);
			return 0;
		} else {
			alarm(1);
			return 1;
		}
		alarm(0);
	};
		alarm(0);
	};

    chomp($@);
    if ($@ eq 'alarm') {
        alarm(0);
        return 1;
    }

    # Return the results ASAP if some of the above results failed
    return $check_results if ($check_results);

    # Let each if handle the return results itself
    if (-l '/var/lib/mysql/mysql.sock') {
        # /tmp/mysql.sock is the socket. Make sure that /var/lib/mysql/mysql.sock is pointing to it
        if (-S '/tmp/mysql.sock') {
            return 0;
        } else {
            return 1;
        }
    } elsif (-S '/var/lib/mysql/mysql.sock') {
        # /var/lib/mysql/mysql.sock is the socket. Make sure that /tmp/mysql.sock is pointing to it
        if (-l '/tmp/mysql.sock') {
            return 0;
        } else {
            return 1;
        }
    } else {
        return 1;
    }
}

1;


