#!/usr/bin/perl
#
#
# Example usage: perl backup_to_s3.pl /folder/to/backup bucket-name-backups folders/in/bucket/to/keep/backup/copies 30
# 


use strict;
use warnings;
use POSIX qw(strftime);
use File::Path qw(make_path remove_tree);
use Time::Local;

# Set UTC to ensure consistent time calculations
$ENV{'TZ'} = 'UTC';

# Variables
my $mysql_user     = $ENV{'MYSQL_USER'}     || 'your_mysql_user';
my $mysql_password = $ENV{'MYSQL_PASSWORD'} || 'your_mysql_password';
my $mysql_host     = $ENV{'MYSQL_HOST'}     || 'localhost';
my $mysql_port     = $ENV{'MYSQL_PORT'}     || '3306';

my $aws_s3_bucket    = $ARGV[0];  # S3 bucket name
my $s3_backup_folder = $ARGV[1];  # S3 folder path under bucket
my $days_to_keep     = $ARGV[2];  # Number of days to keep backups
my $aws_cli          = $ARGV[3] || '/usr/local/bin/aws';  # AWS CLI binary, default to 'aws'

# Temporary backup directory
my $temp_backup_dir = "$ENV{'HOME'}/.backups_sql";
my $date            = strftime("%Y-%m-%d_%H-%M-%S", localtime);

# Slack webhook URL & channel
my $slack_webhook_url = $ENV{'SLACK_WEBHOOK_URL'} || '';
my $slack_channel     = $ENV{'SLACK_CHANNEL'}     || '#backups';
my $slack_username    = $ENV{'SLACK_USERNAME'}    || 'MySQL Backup Script';

# Temporary backup directory
my $temp_backup_dir = "$ENV{'HOME'}/.backups_sql";
my $date            = strftime("%Y-%m-%d", localtime);
my $current_time    = time();

# Slack webhook URL & channel
my $slack_webhook_url = $ENV{'SLACK_WEBHOOK_URL'} || '';
my $slack_channel     = $ENV{'SLACK_CHANNEL'}     || '#backups';
my $slack_username    = $ENV{'SLACK_USERNAME'}    || 'MySQL Backup Script';

# Function to send Slack notification
sub send_slack_notification {
    my ($message, $is_error) = @_;
    return unless $slack_webhook_url;

    my $icon_emoji = $is_error ? ':x:' : ':white_check_mark:';

    # Escape double quotes and backslashes
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

    # Send the notification
    my $curl_command = qq|curl -s -m 5 --data-urlencode '$payload' '$slack_webhook_url'|;
    my $curl_response = `$curl_command 2>&1`;
    my $curl_exit_status = $? >> 8;

    # Check if curl command was successful
    if ($curl_exit_status != 0) {
        warn "Warning: Failed to send Slack notification. Curl exited with status $curl_exit_status\n";
        warn "Curl Response: $curl_response\n";
    }
}

# Validate input
if (!$aws_s3_bucket || !$s3_backup_folder || !$days_to_keep) {
    my $error_message = "Error: Missing required arguments.\nUsage: $0 <AWS_S3_BUCKET> <S3_BACKUP_FOLDER> <DAYS_TO_KEEP> [AWS_CLI_BINARY]";
    send_slack_notification($error_message, 1);
    die $error_message;
}

if ($days_to_keep !~ /^\d+$/ || $days_to_keep <= 0) {
    my $error_message = "Error: DAYS_TO_KEEP must be a positive integer.";
    send_slack_notification($error_message, 1);
    die $error_message;
}

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

# Create temporary backup directory
if (-d $temp_backup_dir) {
    print "Temporary backup directory exists. Deleting and recreating it...\n";
    remove_tree($temp_backup_dir) or warn "Warning: Failed to delete temporary backup directory.\n";
}
make_path($temp_backup_dir) or do {
    my $error_message = "Error: Failed to create temporary backup directory.";
    send_slack_notification($error_message, 1);
    die $error_message;
};

# Get list of databases
my @databases;
if ($mysql_db) {
    # If a specific database is specified
    @databases = ($mysql_db);
} else {
    # Retrieve list of all databases
    print "Retrieving list of databases...\n";
    my $databases_cmd = "mysql -u \"$mysql_user\" -p\"$mysql_password\" -h \"$mysql_host\" -P \"$mysql_port\" -e \"SHOW DATABASES;\"";
    my @databases_output = `$databases_cmd 2>&1`;
    if ($? != 0) {
        my $error_message = "Error: Failed to retrieve list of databases.\nMySQL Error: @databases_output";
        send_slack_notification($error_message, 1);
        die $error_message;
    }
    @databases = grep { !/^(Database|information_schema|performance_schema|mysql|sys)$/ } map { chomp; $_ } @databases_output;
    if (!@databases) {
        my $error_message = "Error: No databases found to back up.";
        send_slack_notification($error_message, 1);
        die $error_message;
    }
}

print "Starting backup of databases...\n";

# Backup each database
foreach my $db (@databases) {
    print "Backing up database: $db\n";
    my $timestamp = time();
    my $filename = "$temp_backup_dir/${db}-$timestamp.sql.gz";
    my $dump_cmd = "mysqldump -u \"$mysql_user\" -p\"$mysql_password\" -h \"$mysql_host\" -P \"$mysql_port\" \"$db\" 2>&1 | gzip > \"$filename\"";
    system($dump_cmd);
    if ($? != 0) {
        my $error_message = "Error: Failed to backup database '$db'.";
        send_slack_notification($error_message, 1);
        warn $error_message;
    } else {
        print "Database '$db' backed up successfully.\n";
    }
}

# Upload backups to S3 with date in the folder name
my $backup_path = "$aws_s3_bucket/$s3_backup_folder/$date";
print "Uploading backups to 's3://$backup_path/'...\n";
my $sync_command = "$aws_cli s3 sync \"$temp_backup_dir/\" \"s3://$backup_path/\" --storage-class STANDARD_IA";
my $sync_output = `$sync_command 2>&1`;
if ($? != 0) {
    my $error_message = "Error: Failed to upload backups to S3.\nAWS CLI Error: $sync_output";
    send_slack_notification($error_message, 1);
    die $error_message;
}

print "Backups uploaded successfully.\n";

# Clean up temporary backup directory
print "Cleaning up temporary files...\n";
remove_tree($temp_backup_dir) or warn "Warning: Failed to delete temporary backup directory.\n";

# Calculate the cutoff timestamp
my $cutoff_time  = $current_time - ($days_to_keep * 86400);  # 86400 seconds in a day

# Remove backups older than the cutoff time
print "Removing backups in 's3://$aws_s3_bucket/$s3_backup_folder' older than $days_to_keep days...\n";
my $list_command = "$aws_cli s3 ls \"s3://$aws_s3_bucket/$s3_backup_folder/\" --recursive";
open my $s3_list, "-|", "$list_command 2>&1" or do {
    my $error_message = "Error: Failed to list files in S3 bucket.";
    send_slack_notification($error_message, 1);
    die $error_message;
};

my $found_backups = 0;

while (<$s3_list>) {
    chomp;
    # Each line has format: date time size path
    if (/^(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})\s+\d+\s+(.*)$/) {
        my $file_date = $1;
        my $file_time = $2;
        my $file_path = $3;
        $found_backups = 1;

        # Parse the date and time from the file path
        if ($file_path =~ m{^(.*?)/(\d{4}-\d{2}-\d{2})/[^/]+-(\d+)\.sql\.gz$}) {
            my $file_folder_date = $2;
            my $file_timestamp   = $3;

            # Convert timestamp to integer
            if ($file_timestamp =~ /^\d+$/) {
                if ($file_timestamp < $cutoff_time) {
                    print "Deleting 's3://$aws_s3_bucket/$file_path'...\n";
                    my $delete_command = "$aws_cli s3 rm \"s3://$aws_s3_bucket/$file_path\"";
                    my $delete_output = `$delete_command 2>&1`;
                    if ($? != 0) {
                        my $warning_message = "Warning: Failed to delete '$file_path'.\nAWS CLI Error: $delete_output";
                        send_slack_notification($warning_message, 1);
                        warn $warning_message;
                    }
                }
            } else {
                warn "Warning: Invalid timestamp in filename '$file_path'. Skipping deletion.";
            }
        } else {
            warn "Warning: File path '$file_path' does not match expected pattern. Skipping.";
        }
    }
}

close $s3_list;

unless ($found_backups) {
    print "No backups found in 's3://$aws_s3_bucket/$s3_backup_folder' to delete.\n";
}

print "Backup process completed successfully.\n";

# Send success notification
my $success_message = "MySQL backups completed successfully and uploaded to 's3://$backup_path/'.";
send_slack_notification($success_message, 0);