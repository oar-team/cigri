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

    ConfLibCigri::init_conf();
    my $smtpServer = ConfLibCigri::get_conf("MAIL_SMTP_SERVER");
    my $mailSenderAddress = ConfLibCigri::get_conf("MAIL_SENDER");
    my $mailRecipientAddress = ConfLibCigri::get_conf("MAIL_RECIPIENT");

    my $smtp = Net::SMTP->new($smtpServer, Timeout => 30, Debug => 1);
    $smtp->mail($mailSenderAddress);
    $smtp->to($mailRecipientAddress);
    $smtp->data();
    $smtp->datasend("Subject: $object\n");
    $smtp->datasend($body);
    $smtp->quit;
}

return 1;

