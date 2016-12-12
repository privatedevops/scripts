#!/usr/bin/perl 

#package create
package check_procs;

#use
use base 'Exporter';
use Fcntl;
use strict;
#use warnings;
use Proc::ProcessTable;

require  LWP::UserAgent;

our @ISA        = qw(Exporter);
our @EXPORT = qw(maxproc);
our $VERSION    = 1.0;
# executes at run-time, unless used as module
# __PACKAGE__->maxproc() unless caller;

sub maxproc {
	# A cheap and sleazy version of ps
	my $FORMAT = "%-6s %-10s %-8s %-24s %s\n";
	my $p = shift;
	my $f = shift;
	my $t = new Proc::ProcessTable;
	my $cmdline=shift;

	our $max_php = 255;
	our $max_dovecot=255555;

	my $pattern_php='/usr/bin/php';
	my $pattern_dovecot='dovecot';

	our $php_lines=0;
	our $dovecot_lines=0;

	my $php_res=shift;
	my $dovecot_res=shift;
	
	
#	#DUMP ALL PROCS
#	printf($FORMAT, "PID", "TTY", "STAT", "START", "COMMAND"); 
#	foreach $p ( @{$t->table} ){
#		printf($FORMAT, $p->pid, $p->ttydev, $p->state, scalar(localtime($p->start)), $p->cmndline);
#	}
#
#
#	 Dump all the information in the current process table
	
	foreach $p (@{$t->table}) {
		foreach $f ($t->fields){
			$cmdline = "$f, $p->{$f}";

			#do PHP
			$cmdline =~ s/exec.*//g ;
			$cmdline =~ s/cmndline,\ //g ;
			if ( $cmdline =~ m/$pattern_php/  ) {
				$php_res = "$cmdline ";
				$php_lines++;
			}
			#do DOVECOT
			$cmdline =~ s/cwd.*//g ;
			$cmdline =~ s/fname.*//g ;
			if ( $cmdline =~ m/$pattern_dovecot/  ) {
			#	print "$cmdline\n";
				$dovecot_res = "$cmdline ";
				$dovecot_lines++;
			}
		}
	}  
	if ( $php_lines > $max_php ) {
		system("killall -9 php httpd /usr/bin/php");
		system("/usr/local/sbin/9");
		return 2;
	} else {
		print "PHPs - $php_lines, max phps - $max_php - OK\n";
	}

	 if ( $dovecot_lines > $max_dovecot ) {
		system("pidof dovecot/imap dovecot/imap-login dovecot/log dovecot/anvil dovecot/config dovecot/auth dovecot/pop3-login dovecot/imap-login | xargs kill -9");
		system("etc/init.d/dovecot restart");
		return 3;
	} else {
		 print "Dovecots - $dovecot_lines, max Dovecot - $max_dovecot - OK\n";
	}

}
#maxproc();
