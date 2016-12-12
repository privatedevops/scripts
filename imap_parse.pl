#!/usr/bin/perl

use strict;
use warnings;    

use MIME::Base64;
use Net::IMAP::Simple;
use LWP::UserAgent; 
use HTTP::Request::Common qw{ POST };
use lib qw(..);
use JSON qw( );
use Data::Dumper;
use Email::Stuff;
use MIME::Lite;
use MIME::Parser ;
use Encode();
use MIME::Entity();
use Mail::Address ;
use HTML::FormatText ;
use HTML::Strip;
use Email::Stuffer;
use Email::MIME;
use Email::Simple;

binmode STDOUT, ':utf8';


my $host = '195.154.133.82';
my $user = 'info';
my $pass = 'abcd1234';
        
# Create the object
my $imap = Net::IMAP::Simple->new($host) ;
      
# Log on
if(!$imap->login($user,$pass)){
	print STDERR "Login failed: Unable to login. \n";
	exit(64);
}

my $newm = $imap->select('INBOX');

# How many messages are there?
my ($unseen, $recent, $num_messages) = $imap->status();
print "\nUnseen emails: $unseen, Recent emails: $recent, Total emails: $num_messages\n\n";
        
for(my $i = 1; $i <= $newm; $i++)
{
	my $es = Email::Simple->new(join '', @{ $imap->top($i) } );
    my $mssg = Email::MIME->new( join '', @{ $imap->get($i) } );   
	my $from = $es->header('Return-Path')."\n";
	my $msgid = $es->header('Message-ID');
	my $rcpt = $es->header('To')."\n";
	my $plainsubject = $es->header('Subject')."\n";
	my $subject = encode_base64($plainsubject);
	my $plainbody = $mssg->body_raw;
	my $text = encode_base64($plainbody);
	my $contenttype = $mssg->content_type;

   # my $tags =  $msg->get_headeref;
   # print "TAGS: $tags\n";
   
   # next;
   
    #do not process old mails
    #if ( $imap->seen($i) ) {
    #    print "Email $msgid is not new\n";
    #    next;
    #}

    chomp $plainbody;
    chomp $plainsubject;
	chomp $from;
	chomp $rcpt;
	chomp $subject;
	chomp $text;
	chomp $msgid;
                            
	printf "\n=====================================================================================\n
	MSG ID: $msgid
	CONTENT-TYPE: $contenttype
	FROM: $from
	TO: $rcpt
	SUBJECT: $plainsubject
	BODY: DISABLED\n
	";

    #sending POST to API content
    my $purl = 'http://test.cardapi.net/mail_logger';
    my $pemail_to = $rcpt;
    my $pemail_from = $from;
    my $psubject = $subject;
    my $pbody= $text;
    my $psecret_key = 'aeg8sdjisd7rft978yFGFH';
    
    my $ua = LWP::UserAgent->new(); 
   
    my %form;
    $form{'email_to'}="$pemail_to";
    #test#  $form{'email_to'}='PLC_482_19@cardapi.net';
    $form{'email_from'}=$pemail_from;
    $form{'subject'}=$psubject;
    $form{'body'}="$pbody";
    $form{'secret_key'}="$psecret_key";

    my $response = $ua->post( $purl, \%form ); 
    my $content = $response->content;
    #print $response;
    #print $content ;
    my $json = JSON->new;
    my $data = $json->decode($content);
    my $apimail = $data->{data}{email};
    #for email debug
    #my $apimail = 'sanek@slacklinux.net';
    if ($apimail) {
        print "APIMAIL FOUND: $apimail, forwarding mail from $from to $apimail\n";
        if ( $contenttype =~ m!text/html! )  {
            print "Sending HTML";	       
            my $msg = MIME::Lite->new(
                From => $from,
                To => $apimail,
                Subject => $plainsubject,
                Data => $plainbody,
                Type => 'TEXT' # or 'text/html','text/html' etc
            );
            $msg->attr("content-type" => "$contenttype");
            $msg->send;
            print "Mail sent to: $apimail";
        } 
        elsif  ( $contenttype =~ m!text/plain! )  
        {
            $plainbody = HTML::Entities::encode_entities($plainbody, "\200-\777");
            $plainbody = HTML::Strip->new->parse($plainbody); 
            $plainbody = $mssg->body_str;        
            print "Sending TEXT PLAIN\n";
            my $msg = MIME::Lite->new(
                From => $from,
                To => $apimail,
                Subject => $plainsubject,
                Data => $plainbody,
                Type => 'TEXT' # or 'text/plain','text/html' etc
            );
            $msg->attr("content-type" => "$contenttype");
            $msg->send;
            print "Mail sent to: $apimail";
        }
        elsif  ( $contenttype =~ m!multipart! ) 
        {
            print "\nChecking body parts\n";
            my $parsed = $mssg;
            my @parts = $mssg->parts;
            my $txtmpbody;
            my $htmlmpbody;
            for my $part (@parts) {    
                my $content_type = $part->content_type;    
                #printf "\nPART:  ".$part->body ()."\n";
                #printf "\nCONTENT TYPE: $content_type";      
                if ($content_type =~ m!text/plain!) {
                    #print "\nTEXT PART IS:<pre>", $part->body (), "</pre>\n";
                    $txtmpbody=$part->body ();
                }
                elsif ($content_type =~ m!text/html!) 
                {
                    #print "Found HTML\n";
                    #print $part->body ();
                    $htmlmpbody=$part->body ();
                }
                elsif ($content_type =~ m!multipart/alternative! or $part->content_type eq '') 
                {
                    #print "Found Multipart\n";
                    #print $part->body ();
                    $htmlmpbody=$part->body ();
                }
                elsif ($content_type =~ m!multipart/signed!) 
                {
                    $htmlmpbody='signing gpg and others not supported';
                    $txtmpbody='signing gpg and others not supported';
                }              
                # Handle some more ccontent types here ...
            }              

            my $msg = MIME::Entity->build(
                From => $from,
                To => $apimail,
                Subject => $plainsubject,
                Type => 'multipart/alternative' # or 'multipart/alternative','text/html' etc
            );
            my $plain = $msg->attach(
                Type => 'text/plain; charset=UTF-8',
                Data => $txtmpbody,
            );              
            my $fancy = $msg->attach( Type => 'multipart/mixed' );
            $fancy->attach(
                Type => 'text/html; charset=UTF-8',
                Data => $htmlmpbody,
            );
            
              #    $fancy->attach(
              #      Type            => 'text/plain; charset=UTF-8',
              #      Disposition     => 'attachment',
              #      Filename        => 'test.txt',
              #      Data            => [ "*Multipart alternative with attachments*\n\nHere comes the attachment." ],
              #    );              
              
              
            # $msg->attr("content-type" => "$contenttype");
                $msg->send; 
            print "\nMail sent to: ".$apimail."\n";
        }
    }
    else
    {
        print "\nEmail forward for not found in API call!\n"
    }
}

# delete all emails in mailbox
my $msgcount=$imap->last;
for my $msgid (0..$msgcount) {
    print "\nMail ID: ".$msgid." deleted from info\@cardapi.net!\n" if $imap->delete( $msgid );
}

#close imap connectiopn
$imap->quit;