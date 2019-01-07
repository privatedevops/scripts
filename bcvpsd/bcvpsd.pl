#!/usr/bin/perl


use strict;
use warnings;
use POSIX;
use File::Pid;

#require  "/root/scripts/check_mysql.pm";
use lib "/root/scripts/bcvpsd/modules/";

## use the checker modules
use check_mysql;
use check_headers;
use check_load; 
use check_smtpfw;
#use brute_force;
use check_procs;
use check_memory;

# make "mydaemon.log" file in /var/log/ with "chown root:adm mydaemon"

# TODO: change "mydaemon" to the exact name of your daemon.
my $daemonName    = "bcvpsd";
#
my $dieNow        = 0;                                     # used for "infinte loop" construct - allows daemon mode to gracefully exit
my $sleepMainLoop = 3;                                    # number of seconds to wait between "do something" execution after queue is clear
my $logging       = 1;                                     # 1= logging is on
my $logFilePath   = "/var/log/";                           # log file path
my $logFile       = $logFilePath . $daemonName . ".log";
my $pidFilePath   = "/var/run/";                           # PID file path
my $pidFile       = $pidFilePath . $daemonName . ".pid";


$ENV{'PATH'} = '/sbin:/usr/sbin:/bin:/usr/bin:/usr/local/sbin:/usr/local/bin';

# daemonize
use POSIX qw(setsid);
chdir '/';
umask 0;
open STDIN,  '/dev/null'   or die "Can't read /dev/null: $!";
open STDOUT, '>>/dev/null' or die "Can't write to /dev/null: $!";
open STDERR, '>>/dev/null' or die "Can't write to /dev/null: $!";
defined( my $pid = fork ) or die "Can't fork: $!";
exit if $pid;

# dissociate this process from the controlling terminal that started it and stop being part
# of whatever process group this process was a part of.
POSIX::setsid() or die "Can't start a new session.";

# callback signal handler for signals.
$SIG{INT} = $SIG{TERM} = $SIG{HUP} = \&signalHandler;
$SIG{PIPE} = 'ignore';

# create pid file in /var/run/
my $pidfile = File::Pid->new( { file => $pidFile, } );

$pidfile->write or die "Can't write PID file, /dev/null: $!";
$0 = '[bcvpsd]';

# turn on logging
if ($logging) {
	open LOG, ">>$logFile";
	select((select(LOG), $|=1)[0]); # make the log file "hot" - turn off buffering
}

# "infinite" loop where some useful process happens
my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
my $dateTime = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec;
my $result = shift;
my $alarm=0;

print LOG "$dateTime [$0] Started\n";

until ($dieNow) {
	sleep($sleepMainLoop);
	my $pid = fork();
	if (not defined $pid) {
		print "resources not avilable.\n";
	} elsif ($pid == 0) {
		#check web headers
		if (check_headers->header_status() == 1 ){
			$result="[Error] Header status problem - Main Website is DOWN";
			logEntry();
			$alarm++;
		} else {
			$result="[OK] Apache is UP";
			logEntry_nomail();
		}
		# check for overload
		if (check_load->loadavg() == 1 ){
			$result="[Error] The server is overloaded - Loadavg: $check_load::cur_load";
			logEntry();
			$alarm++;
		} else {
			$result="[OK] Load is OK - Load: $check_load::cur_load";
			logEntry_nomail();
		}
                # check for freemem
                if (check_memory->memavg() == 1 ){
                        $result="[Error] The server has low memory - Free RAM: $check_memory::freememory MB";
                        logEntry();
                        $alarm++;
                } else {
                        $result="[OK] RAM usage is OK - Free RAM: $check_memory::freememory MB";
                        logEntry_nomail();
                }
		# check for broken dbs
		if (check_mysql->broken_db() == 1 ){
			$result="[Error] MySQL Not OK - Broken DBs detected";
			logEntry();
			$alarm++;
		} else {
			$result="[OK] MySQL logs are ok, no issues found.";
			logEntry_nomail();
		}
		#check for direct mysql connection
		if (check_mysql->mysql_check() == 1 ){
			$result="[Error] Unable to connect to to mysql server DBI connect";
			logEntry();
			$alarm++;
		} else {
			$result="[OK] MySQL is UP";
			logEntry_nomail();
		}
		#check if 25 port tcp is blocked by iptables
		if (check_smtpfw->check_smtpfw() == 1 ){
			$result="[Error] SMTP DROP or REJECT rules found, firewall restarted.";
			logEntry();
			$alarm++;
		} else {
			$result="[OK] SMTP is not blocked by firewall";
			logEntry_nomail();
		}
		#run brute-force detector
		#if (brute_force->add_rules() == 2 ){
		#	$result="[Error] $brute_force::IP blocked - $brute_force::NOTES";
		#	logEntry_nomail();
		#	$alarm++;
		#} else {
		#	$result="[OK] DDoS protected";
		#	logEntry_nomail();
		#}
	        #run brute-force expire check
	        #if (brute_force->del_rules() == 3 ){
		#	$result="[Error] $brute_force::d_ip removed from firwall block list";
		#	logEntry_nomail();
		#	$alarm++;
		#} else {
		#	$result="[OK] All DDoS IPs are active";
		#	logEntry_nomail();
	        #}
		#run check max php procs
		if (check_procs->maxproc() == 2 ){
			$result="[Error] Too many PHP processes found: $check_procs::php_lines, killing them and apache restart.";
			logEntry();
			$alarm++;
		} else {
			$result="[OK] PHP processes: $check_procs::php_lines, limit is: $check_procs::max_php";
			logEntry_nomail();
		}
		#run check max dovecot procs
		if (check_procs->maxproc() == 3 ){
			$alarm++;
			$result="[Error] Too many DOVECOT processes found: $check_procs::dovecot_lines, killing them and dovecot restart.";
			logEntry();
		} else {
			$result="[OK] DOVECOT processes: $check_procs::dovecot_lines, limit is: $check_procs::max_dovecot";
			logEntry_nomail();
		}
		$result="================================================================================================";
		logEntry_nomail();
		#######################
		die();
	} else {
		waitpid($pid,0);
	}
	
	# add a line to the log file
	sub logEntry {
		my ($logText) = @_;
		my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
		my $dateTime = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec;
		if ($logging) {
			print LOG "$dateTime $result\n";
			notification();
		}
	}

	sub logEntry_nomail {
		my ($logText) = @_;
		my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
		my $dateTime = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec;
		if ($logging) {
			print LOG "$dateTime $result\n";
		}
	}

	#funk. to send email
	sub notification {
		# email setup
		my $to='support@bgcode.com';
		my $from='root@vm1.bgcode.com';
		my $subject='PROBLEM';
		open(MAIL, "|/usr/sbin/sendmail -t");
		## Mail Header
		print MAIL "To: $to\n";
		print MAIL "From: $from\n";
		print MAIL "Subject: $subject\n\n";

		## Mail Body
		my $out = sprintf("PROBLEM: $dateTime $result\n");

		print MAIL $out;
		close(MAIL);
	}

}
# catch signals and end the program if one is caught.
sub signalHandler {
	$dieNow = 1;    # this will cause the "infinite loop" to exit
}

# do this stuff when exit() is called.
END {
	if ($logging) { close LOG }
	$pidfile->remove if defined $pidfile;
}
