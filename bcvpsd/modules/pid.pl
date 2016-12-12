#!/usr/bin/perl
use strict;
use warnings;



sub main {
    my $self = shift;
    sub logger { print @_, "\n"; }
    our %proc = ();
    our %stats = ();
    gather_proc_info(\%stats,\%proc);
    while ( my $pid = each(%proc)) {
        printf "Pid: %d Owner: %d State: %s CMD: %s\n", $pid, $proc{$pid}[0], $proc{$pid}[3], $proc{$pid}[2];
    }
}

sub gather_proc_info {
my $stats_ref = shift;
my $proc_ref = shift;
my @pid_info = ();
my $cmdline = '';
my @stat = ();
my @io = ();

	opendir PROC, '/proc' or main::logger("Unable to open dir /proc: $!");
	while ( my $pid = readdir(PROC) ) {
        # cycle only trough the PIDs
        if ($pid =~ /^[0-9]+$/) {
            # pid_info[4] - UID
            # pid_info[9] - Process creation time
            # stat[2] - process state
            # stat[3] - pid of the parent process
            # stat[18] - nice level
            # stat[14] - process utime
            # stat[15] - process stime
            # stat[] - process memory
            if ( @pid_info = stat("/proc/$pid") ) {
                $cmdline = <CMDLINE> if open CMDLINE, '<', "/proc/$pid/cmdline";
                @stat = split / /, <STAT> if open STAT, '<', "/proc/$pid/stat";
                @io = <IO> if open IO, '<', "/proc/$pid/io";
                close CMDLINE;
                close STAT;
                close IO;

                if ( defined($stat[3]) ) {
                    if (defined($cmdline)) {
                        $cmdline =~ s/\0*$//;
                        $cmdline =~ s/[\0|\r|\n]/ /g;
                    } else {
                        $cmdline = $stat[1];
                    }
                    # update the stats
                    if ($pid_info[4] != 0) {
                        if (defined($io[0]) && defined($io[1])) {
                            $io[0] =~ s/^.* ([0-9]+)\n/$1/;
                            $io[1] =~ s/^.* ([0-9]+)\n/$1/;
                            # populate the statsics
                            if ( exists $stats_ref->{$pid_info[4]} ) {
                                $stats_ref->{$pid_info[4]}[2] += $io[0];
                                $stats_ref->{$pid_info[4]}[3] += $io[1];
                            } else {
                                $stats_ref->{$pid_info[4]}[2] = $io[0];
                                $stats_ref->{$pid_info[4]}[3] = $io[1];
                            }
                            $stats_ref->{$pid_info[4]}[1]++;
                            ${$stats_ref->{$pid_info[4]}[0]}{$pid} = 1;
                            $stats_ref->{'global'}[0] += $io[0];
                            $stats_ref->{'global'}[1] += $io[1];
                        }
                        $stats_ref->{'global'}[2]++;
                    }
                    # put the info into the process table hash
                    $proc_ref->{$pid} = [ $pid_info[4], $pid_info[9], $cmdline, $stat[2], $stat[17], $stat[18], $stat[3], $stat[5], $stat[14], $stat[15] ];
                }
            }
        }
    }
    closedir PROC;

}

sub kill_zombies {
    my $proc_stats_ref = shift;
    # kill all zombie processes
    if ($#{$proc_stats_ref->{'kills'}} != -1) {
#       kill 9, @{$proc_stats_ref->{'kills'}};
        my $killed_pids = '';
        my $count = kill 9, @{$proc_stats_ref->{'kills'}};
#       foreach my $pid(@{$proc_stats_ref->{'kills'}}) {
#           $killed_pids .= $pid . ' ';
#       }
#       main::kill_log("Killed zombie procs($count): $killed_pids");
        $proc_stats_ref->{'kills'} = [];
    }
}

sub kill_long_procs {
    my $proc_stats_ref = shift;
    my $proc_ref = shift;
    my $loadtype = shift;
    my $current_time = shift;
    my $curload = shift;
    my $load_vars_ref = shift;
    my $user_ref = shift;
    my @kill_list = ();
    # kill all long processes if they are imap or php and the load is increasing
    for my $pid (@{$proc_stats_ref->{'long_processes'}}) {
                #printf main::STATUS "%d\t%s %d\t%s\n", $pid, $proc_ref->{$pid}[3], $proc_ref->{$pid}[4], $proc_ref->{$pid}[2];
				print @kill_list;
                push(@kill_list, $pid);

    }
	print @kill_list;
#    kill 15, @kill_list;
}
#kill_long_procs(\%proc_stats, \%proc, $loadtype, $current_time, $curload, \@load_vars, \%users);
kill_zombies();
gather_proc_info();
kill_long_procs();
