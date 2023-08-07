#!/usr/bin/perl
#
#       Copyrights Private Devops LTD. - https://privatedevops.com
#

use strict;
use warnings;

# required modules
use Net::IMAP::Simple;
use Email::Simple;
use IO::Socket::SSL;


# fill in your details here
my $username = 'username@gmail.com';
my $password = 'password';
my $mailhost = 'pop.gmail.com';

# Connect
my $imap = Net::IMAP::Simple-&gt;new(
$mailhost,
port =&gt; 993,
use_ssl =&gt; 1,
) || die "Unable to connect to IMAP: $Net::IMAP::Simple::errstr\n";

# Log in
if ( !$imap-&gt;login( $username, $password ) ) {
print STDERR "Login failed: " . $imap-&gt;errstr . "\n";
exit(64);
}
# Look in the the INBOX
my $nm = $imap-&gt;select('INBOX');

# How many messages are there?
my ($unseen, $recent, $num_messages) = $imap-&gt;status();
print "unseen: $unseen, recent: $recent, total: $num_messages\n\n";


## Iterate through unseen messages
for ( my $i = 1 ; $i &lt;= $nm ; $i++ ) {
if ( $imap-&gt;seen($i) ) {
next;
}
else {
my $es = Email::Simple-&gt;new( join '', @{ $imap-&gt;top($i) } );

printf( "[%03d] %s\n\t%s\n", $i, $es-&gt;header('From'), $es-&gt;header('Subject') );
}
}


# Disconnect
$imap-&gt;quit;

exit;
