package mailer;

use Data::Dumper;
BEGIN {
	my ($scriptPathTmp) = $0 =~ m!(.*/*)!s;
	my ($scriptPath) = readlink($scriptPathTmp);
	if (!defined($scriptPath)){
		$scriptPath = $scriptPathTmp;
	}
	# Relative path of the package
	my @relativePathTemp = split(/\//, $scriptPath);
	my $relativePath = "";
	for (my $i = 0; $i < $#relativePathTemp; $i++){
		$relativePath = $relativePath.$relativePathTemp[$i]."/";
	}
	$relativePath = $relativePath."../";
	# configure the path to reach the lib directory
	unshift(@INC, $relativePath."lib");
	unshift(@INC, $relativePath."Iolib");
	unshift(@INC, $relativePath."Net");
	unshift(@INC, $relativePath."Colombo");
    unshift(@INC, $relativePath."ClusterQuery");
}
use warnings;
use strict;
use iolibCigri;
use ConfLibCigri;
use Net::SMTP;

# arg1 --> object
# arg2 --> body
sub sendMail($$){
    my $object = shift;
    my $body = shift;

    my $pid=fork;
    if ($pid == 0){
        ConfLibCigri::init_conf();
        my $smtpServer = ConfLibCigri::get_conf("MAIL_SMTP_SERVER");
        my $mailSenderAddress = ConfLibCigri::get_conf("MAIL_SENDER");
        my $mailRecipientAddress = ConfLibCigri::get_conf("MAIL_RECIPIENT");

        print("[MAILER] I send a mail to $mailRecipientAddress with the sender $mailSenderAddress on the server $smtpServer\n");

        my $smtp = Net::SMTP->new($smtpServer, Timeout => 240);
        if (!defined($smtp)){
            my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
            $year += 1900;
            $mon += 1;
            open(FILE, ">> /tmp/ERROR_CIGRI_mailer.log");
            my $str = "Can t send an email to $mailRecipientAddress from $mailSenderAddress; Object : $object ;; Body : $body";
            print(FILE "[$year-$mon-$mday $hour:$min:$sec] $str\n");
            print("[ERROR MAILER] $str\n");
            close(FILE);
        }else{
            $smtp->mail($mailSenderAddress);
            $smtp->to($mailRecipientAddress);
            $smtp->data();
            $smtp->datasend("Subject: $object\n");
            $smtp->datasend($body);
            $smtp->quit;
            print("Mailer OK\n");
        }
    }
}

return 1;

