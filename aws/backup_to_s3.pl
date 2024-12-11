#!/usr/bin/perl
#
#
# Example usage: perl backup_to_s3.pl /folder/to/backup bucket-name-backups folders/in/bucket/to/keep/backup/copies 30
# 



use strict;
use warnings;
use Time::Local;
use POSIX qw(strftime);

# Set UTC to ensure consistent time calculations
$ENV{'TZ'} = 'UTC';

# Variables
my $folder_to_backup  = $ARGV[0];  # Local folder path to backup
my $aws_s3_bucket     = $ARGV[1];  # S3 bucket name
my $s3_backup_folder  = $ARGV[2];  # S3 folder path under bucket
my $days_to_keep      = $ARGV[3];  # Number of days to keep backups
my $aws_cli           = $ARGV[4] // 'aws';  # AWS CLI binary, default to 'aws'

# Slack webhook URL & channel
my $slack_webhook_url = 'https://hooks.slack.com/services/.....';
my $slack_channel     = '#backups';     # Slack channel to post notifications
my $slack_username    = 'AWS s3 Backups Script'; # Slack username to display

# Function to send Slack notification
sub send_slack_notification {
    my ($message, $is_error) = @_;
    return unless $slack_webhook_url;  # Do nothing if webhook URL is not set

    my $icon_emoji = $is_error ? ':x:' : ':white_check_mark:';

    # Escape double quotes and backslashes in variables
    $message     =~ s/([\\"])/\\$1/g;
    my $channel  = $slack_channel;
    $channel     =~ s/([\\"])/\\$1/g;
    my $username = $slack_username;
    $username    =~ s/([\\"])/\\$1/g;

    # Construct the payload
    my $payload = qq|payload={
        "channel": "$channel",
        "username": "$username",
        "icon_emoji": "$icon_emoji",
        "text": "$message"
    }|;

    # Remove newlines and extra spaces
    $payload =~ s/\s+/ /g;
    $payload =~ s/^\s+|\s+$//g;

    # Send the notification using curl with --data-urlencode
    my $curl_command = qq|curl -s -m 5 --data-urlencode '$payload' '$slack_webhook_url'|;

    # Execute the curl command
    my $curl_response = `$curl_command 2>&1`;
    my $curl_exit_status = $? >> 8;

    # Check if curl command was successful
    if ($curl_exit_status != 0) {
        warn "Warning: Failed to send Slack notification. Curl exited with status $curl_exit_status\n";
        warn "Curl Response: $curl_response\n";
    }
}

# Validate input
if (!$folder_to_backup || !$aws_s3_bucket || !$s3_backup_folder || !$days_to_keep) {
    my $error_message = "Error: Missing required arguments.\nUsage: $0 <FOLDER_TO_BACKUP> <AWS_S3_BUCKET> <S3_BACKUP_FOLDER> <DAYS_TO_KEEP> [AWS_CLI_BINARY]";
    send_slack_notification($error_message, 1);
    die $error_message;
}

if ($days_to_keep !~ /^\d+$/ || $days_to_keep <= 0) {
    my $error_message = "Error: DAYS_TO_KEEP must be a positive integer.";
    send_slack_notification($error_message, 1);
    die $error_message;
}

# Check if folder exists
if (!-d $folder_to_backup) {
    my $error_message = "Error: FOLDER_TO_BACKUP '$folder_to_backup' does not exist.";
    send_slack_notification($error_message, 1);
    die $error_message;
}

# Ensure folder path does not end with a slash
$folder_to_backup =~ s{/$}{};

# Check if AWS CLI is available
my $aws_cli_check = `$aws_cli --version 2>&1`;
if ($? != 0) {
    my $error_message = "Error: AWS CLI not found or not executable. Please install AWS CLI and ensure it's in your PATH.";
    send_slack_notification($error_message, 1);
    die $error_message;
}

# Check if S3 bucket exists
print "Checking if S3 bucket 's3://$aws_s3_bucket' exists...\n";
my $bucket_check = `$aws_cli s3 ls "s3://$aws_s3_bucket" 2>&1`;
if ($? != 0) {
    my $error_message = "Error: S3 bucket 's3://$aws_s3_bucket' does not exist or is inaccessible.\nAWS CLI Error: $bucket_check";
    send_slack_notification($error_message, 1);
    die $error_message;
}

# Get today's date in US format (MM-DD-YYYY)
use POSIX qw(setlocale LC_TIME);
setlocale(LC_TIME, "C");
my $date = strftime("%m-%d-%Y", localtime);

# Create today's backup folder in S3 bucket
my $backup_path = "$aws_s3_bucket/$s3_backup_folder/$date";

# Sync the folder to the dated S3 subfolder
print "Syncing '$folder_to_backup' to 's3://$backup_path/'...\n";
my $sync_command = "$aws_cli s3 sync \"$folder_to_backup\" \"s3://$backup_path/\" --delete --exact-timestamps";
my $sync_output = `$sync_command 2>&1`;
if ($? != 0) {
    my $error_message = "Error: Failed to sync folder to S3 bucket.\nAWS CLI Error: $sync_output";
    send_slack_notification($error_message, 1);
    die $error_message;
}

# Calculate the cutoff timestamp
my $current_time = time();
my $cutoff_time  = $current_time - ($days_to_keep * 86400);  # 86400 seconds in a day

# Remove backups older than the cutoff time
print "Removing backups in 's3://$aws_s3_bucket/$s3_backup_folder' older than $days_to_keep days...\n";
open my $s3_list, "-|", "$aws_cli s3 ls \"s3://$aws_s3_bucket/$s3_backup_folder/\" 2>&1" or do {
    my $error_message = "Error: Failed to list files in S3 bucket.";
    send_slack_notification($error_message, 1);
    die $error_message;
};

my $found_backups = 0;

while (<$s3_list>) {
    chomp;
    if (/^\s*PRE\s+(\d{2}-\d{2}-\d{4})\/\s*$/) {
        my $folder_name = $1;
        $found_backups = 1;

        # Convert folder date to timestamp
        my ($month, $day, $year) = split('-', $folder_name);
        my $folder_time_unix = eval { timelocal(0, 0, 0, $day, $month - 1, $year) };
        if ($@) {
            warn "Warning: Failed to parse date '$folder_name'. Skipping deletion.";
            next;
        }

        # Delete folder if older than cutoff time
        if ($folder_time_unix < $cutoff_time) {
            print "Deleting 's3://$aws_s3_bucket/$s3_backup_folder/$folder_name/'...\n";
            my $delete_command = "$aws_cli s3 rm \"s3://$aws_s3_bucket/$s3_backup_folder/$folder_name/\" --recursive";
            my $delete_output = `$delete_command 2>&1`;
            if ($? != 0) {
                my $warning_message = "Warning: Failed to delete '$folder_name'.\nAWS CLI Error: $delete_output";
                send_slack_notification($warning_message, 1);
                warn $warning_message;
            }
        }
    }
}

close $s3_list;

unless ($found_backups) {
    print "No backups found in 's3://$aws_s3_bucket/$s3_backup_folder' to delete.\n";
}

print "Backup process completed successfully.\n";

# Send success notification
#my $success_message = "Backup completed successfully for '$folder_to_backup' to 's3://$backup_path/'.";
#send_slack_notification($success_message, 0);