#!/usr/bin/perl -w
############################################################################
#
#	Simple Mail Proxy
#
############################################################################
$ENV{'PATH'} = '/sbin:/usr/sbin:/bin:/usr/bin:/usr/local/sbin:/usr/local/bin:/usr/share/perl5:/usr/share/perl5/vendor_perl:/usr/lib64/perl5:/root/perl5/lib/perl5';

use Carp;
use Net::SMTP;
use Net::SMTP::Server;
use base qw(Net::Server::PreFork);

use Mail::Message;
use Sys::Hostname;

#mine
use Encode();
use Encode qw(decode encode);
use LWP::UserAgent; 
use HTTP::Request::Common qw{ POST };
use lib qw(..);
use JSON qw( );
use Data::Dumper;
use utf8;
use Encode qw( from_to is_utf8 );
use Encode::Detect::Detector;
use POSIX;
use File::Pid;
use Proc::Daemon;
use Email::Address;
use IO::Socket::Timeout;
use Parallel::ForkManager;
my $MAX_PROCESSES = 50;


my $debug = 0;
#to debug disable next line with, enable debug  from the prev. line#
Proc::Daemon::Init;



my $logging = 1;  

my $scriptname    = "smtp-proxy";
my $logFilePath   = "/var/log/";                           # log file path
my $logFile       = $logFilePath . $scriptname . ".log";
my $pidFilePath   = "/var/run/";                           # PID file path
my $pidFile       = $pidFilePath . $scriptname . ".pid";

# dissociate this process from the controlling terminal that started it and stop being part
# of whatever process group this process was a part of.
POSIX::setsid() or die "Can't start a new session.";

# callback signal handler for signals.
$SIG{INT} = $SIG{TERM} = $SIG{HUP} = \&signalHandler;
$SIG{PIPE} = 'ignore';

# create pid file in /var/run/
my $pidfile = File::Pid->new( { file => $pidFile, } );

$pidfile->write or die "Can't write PID file, /dev/null: $!";
$0 = '[smtp-proxy]';

# turn on logging
if ($logging) {
	open LOG, ">>$logFile";
	select((select(LOG), $|=1)[0]); # make the log file "hot" - turn off buffering
}

# "infinite" loop where some useful process happens
my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
my $dateTime = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec;
my $result = shift;
my $noresult = shift;

## SMTP server address and port ##
#
my $SMTP_Server_Address = '195.154.133.82';
my $SMTP_Server_Port = 2525;


### Mail proxy (this server) address and port ##
#
my $Proxy_Port = 25;


#===========================================================================
#	Mail client connection service
#===========================================================================

### Constants ###

my $SUCCEEDED = 0;

my %commands = (DATA => \&cmd_data,
		EXPN => \&cmd_dummy,
		HELO => \&cmd_helo,
		HELP => \&cmd_help,
		MAIL => \&cmd_mail,
		NOOP => \&cmd_noop,
		QUIT => \&cmd_quit,
		RCPT => \&cmd_rcpt,
		RSET => \&cmd_rset,
		VRFY => \&cmd_dummy);

### Variables ###

my $client_socket;
my $from;
my @to;
my $message;

my $apimail;
my $apito;
my $apifrom;

my $psubject;
my $pbody;
my $body;
my $subject;

my $relaydomains = "/etc/postfix/domains";
my @localdomains = '';

sub client_put ($) {
    my ($message) = @_;
    print "Sent:     $message\n" if ($debug);
    print $client_socket $message, "\r\n";
}

sub cmd_data () {
    if (!defined($from)) {
        client_put("503 5.5.1 Sender address not yet specified");
        return 1;
    };
    if (!@to) {
        client_put("503 5.5.1 Recepient address not yet specified");
        return 1;
    };
    client_put("354 Start mail input; end with .");

    my $done = 0;
    while (<$client_socket>) {
        # print "Received: $_" if ($debug);
        if (/^\.\r\n$/) {
            $done = 1;
            last;
        };
        s/^\.\./\./;
        $message .= $_;
    };
    if (!$done) {
    	client_put("451 5.6.0 Message input failed");
    	return 1;
    };
    return 0;
}

sub cmd_helo () {
    client_put("250-Action completed, okay");
    client_put("250 ENHANCEDSTATUSCODES");
}

sub cmd_help () {
    my $out = "214-Commands\r\n";
    my $total = keys %commands;
    my $i = 0;
    foreach my $cmd (keys %commands) {
        $out .= "\r\n214";
        if ($i++ % 5 != 0) {
            $out .= $total - $i < 5 ? " " : "-";
        } else {
            $out .= " ";
        };
    };
    client_put($out);
}

sub cmd_noop () {
    client_put("252 Unknown status, but attempting delivery");
}

sub cmd_quit () {
    client_put("221 Service closing");
    $client_socket->close();
    return 0;
}

sub cmd_mail ($) {
    my ($arg)  = @_;
    $arg =~ /FROM:\s*(\S+)$/i;
    $from = $1;
    $apifrom = $from;
    client_put("250 Mail sender okay");
}

sub cmd_rcpt ($) {
    my ($arg) = @_;
    $arg =~ /To:\s*(\S+)$/gi;
    my $to = $1;
    $apito = $to;
    push(@to, $to);
    read_localdomains ();
}

sub cmd_rset () {
    $from = undef;
    @to = ();
    client_put("250 Reset action okay");
}

sub check_api () {
    #sending POST to API content
    require MIME::Base64;
    my $purl = 'http://test.cardapi.net/mail_logger';
    
    $apito =~ s/<//;
    $apito =~ s/>//;
    
    $apifrom =~ s/<//;
    $apifrom =~ s/>//;
	   
    my $pemail_to = $apito;
    my $pemail_from = $apifrom;

    #plain# $psubject = $subject;   
    $psubject =  MIME::Base64::encode_base64($subject);
    
    #plain body# $pbody =  $body;
    $pbody =  MIME::Base64::encode_base64($body);

    my $psecret_key = 'aeg8sdjisd7rft978yFGFH';
    my $ua = LWP::UserAgent->new(); 

    my %form;
    $form{'email_to'}=$pemail_to;
    #$form{'email_to'}='PLC_507_293@cardapi.net';
    $form{'email_from'}=$pemail_from;
    $form{'subject'}=$psubject;
    $form{'body'}=$pbody;
    $form{'secret_key'}=$psecret_key;

    my $response = $ua->post( $purl, \%form ); 
    my $content = $response->content;

    $result = "[API RETURN]".$content;
    logEntry();			

    my $json = JSON->new; 
    
    my $data = $json->decode($content);
    $apimail = $data->{data}{email};
    #$apimail = 'sanek@slacklinux.net';
}

# add a line to the log file - logging
sub logEntry {
    my ($logText) = @_;
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) = localtime(time);
    my $dateTime = sprintf "%4d-%02d-%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec;
    if ($logging) 
    {
        print LOG "$dateTime $result\n";
    }
}

sub read_localdomains () {
    open(INFO, $relaydomains) or die("Could not open  file."); 
    @localdomains='';
    foreach my $line (<INFO>)  {
        push (@localdomains, $line);
    }
    close(INFO);
    
    my $relaystatus=0;
    
    my ($rcpdomain) = Email::Address->parse("$apito");
    $rcpdomain = $rcpdomain->host;
    for my $localdomain (@localdomains) {
        if ( $localdomain =~ /^$/ ) {
            next;
        }
        if ( $localdomain =~ /$rcpdomain/ ) {
            $result="RELAY $rcpdomain FOUND";
            logEntry();	
            $relaystatus++;
        }    
    }
    if ( $relaystatus > 0 ) {
        client_put("250 2.1.0 Ok - Mail rcpt for domain $rcpdomain and email: <$apito> OK, relay Granted !");
        $result="RELAY FOR $apito OK";
        logEntry();	
    } else { 
        client_put("454 4.7.1: Relay access denied for $rcpdomain and <$apito> !!!");
        $result="RELAY DENIED for $apito";
        logEntry();
        $client_socket->close();
        return 1;
    }
}

sub cmd_dummy () {
}

#===========================================================================
#	SMTP server connection service
#===========================================================================

### relay ($from, @to, $msg) ###
#   forward a mail to specified SMTP server
#
sub relay ($\@$) {
    my ($from, $to, $msg) = @_;
    
    $from =~ /<.*@(.*)>/;
    my $domain = $1;
    print "Domain: $domain\n" if ($debug);
    my $client = new Net::SMTP($SMTP_Server_Address, Port => $SMTP_Server_Port,
			       Hello => $domain, Timeout => 30, Threads => 50, Sleep => 5, Debug => $debug) ||
	croak "Unable to connect to mail server: $!\n";
    if ($client) {
	$client->mail($from);
	foreach my $recipient (@$to) {
	    $client->to($recipient);
	};
        $client->data($msg);
        $client->quit() || croak "Relay failed: $!\n";
    };
}

#===========================================================================
#	Main
#===========================================================================

# turn on logging
if ($logging) {
	open LOG, ">>$logFile";
	select((select(LOG), $|=1)[0]); # make the log file "hot" - turn off buffering
}

print LOG "$dateTime $0 Started\n";

#my $server = new Net::SMTP::Server(hostname(), $Proxy_Port) ||
my $server = new Net::SMTP::Server('0.0.0.0', $Proxy_Port, Timeout => 10, Threads => 10, Sleep => 5, GlobalTimeout => 10) ||
    croak "Unable to create a new mail proxy: $!\n";	

$pm = new Parallel::ForkManager($MAX_PROCESSES);

while ($client_socket = $server->accept()) {
    $pm->start and next; #run child
    
    $from = undef;
    @to = ();
    $message = undef;
    my $accepted;

    client_put("220 Service ready");

    while (<$client_socket>) {
        print "Received: $_" if ($debug);
        chomp;
        my ($cmd, $arg);
        /^\s*(\S+)(\s+(.*\S))?\s*$/;
        $cmd = $1;
        $arg = $3;
        $cmd =~ tr/a-z/A-Z/;
        if (!defined($commands{$cmd})) {
            client_put("500 5.5.2 Syntax error, command unrecognized");
            next;
        };

        &{$commands{$cmd}}($arg);

        if ($cmd eq 'DATA') {
            my $msg = Mail::Message->read($message);
            $body = $msg->body;
            $subject =  $msg->subject;
            if ($body =~ /viagra/i) {
                client_put("554 5.6.0 Invalid keyword included: viagra");
                $accepted = 0;
            } else {
                client_put("250 2.0.0 Message accepted for delivery");
                $accepted = 1;
            };
        };
    };

    $client_socket->close();

    if ($accepted) {
        $result = "[MAIL LOG START]";
        logEntry();
        #relay via proxy to smtp - postfix
    	check_api (); 
     	
	if ( $apimail ) {
        $message =~ s/$apito/$apimail/ig;
        
        $apimail =~ s/^/</;
        $apimail =~ s/$/>/;

	    my @toapi = ();
        push(@toapi, $apimail);        
        $apito =~  s/^/</;
        $apito =~  s/$/>/;

        $apifrom =~ s/^/</;
        $apifrom =~ s/$/>/;         
        
	    relay($from, @toapi, $message);
	    $result="[API MAILTO FOUND]:\nFROM: $apifrom\nAPIMAIL: $apimail\nTO: $apito\nSUBJECT: $psubject\n\nBODY:\n$pbody\n";
	    logEntry();
        } else {
                #print ("\nFROM: $apifrom\nAPIMAIL: NONE\nTO: $apito\nSUBJECT: $psubject\n\nBODY:\n$pbody\n");
	        relay($from, @to, $message); 
	        $result="[API MAILTO NOT FOUND]:\nFROM: $from\nAPIMAIL: NONE\nTO: $apito\nSUBJECT: $psubject\n\nBODY:\n$pbody\n";
		logEntry();
	    }  
	    # do this stuff when exit() is called.
        END {
            if ($logging) { close LOG }
            $pidfile->remove if defined $pidfile;
        } 
        $result="[MAIL LOG END]\n";
	    logEntry();        
    };
    $pm->finish; # do the exit in the child process
    $pm->wait_all_children;
}