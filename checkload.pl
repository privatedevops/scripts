#!/usr/bin/perl
use Proc::Simple;

$myproc = Proc::Simple->new();



foreach $part(@ARGV) {
        if ($part =~ /\*/) {
                print "Stars only in the sky \n";
                exit;
        }
}

$myproc->start("@ARGV");
$pid = $myproc->pid;

while(1) {
	sleep(2);
	open(LOAD, '/proc/loadavg');
	$loadvalues = <LOAD>;
	close(LOAD);
	($curload,$loadlast5, $loadlast15) = split(/\s+/,$loadvalues);

	if ($curload > "4") {
        	print "[stop]";
	        $running = $myproc->poll();

        	if($running eq "0") {
		  	}else{
                	system("renice +19 -p $pid");
	                system("kill -STOP $pid");
        	}
	} else {
        	$running = $myproc->poll();
	        if ($running eq "0") {
        	        exit($myproc->exit_status());
	        } else {
                	system("kill -CONT $pid");
	                print "[loadavg is ok]";

        	}
	}
}
