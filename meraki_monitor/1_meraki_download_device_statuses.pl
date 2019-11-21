#!/usr/bin/perl
use strict;
use warnings;
use LWP;

my $orgid = $ARGV[0];
my $apikey = $ARGV[1];
my $file_devicestatus = $ARGV[2];
my $lockfilename = 'downloading.lock';
my $mustdie = 0;

if (!defined($orgid) || !defined($apikey) || !defined($file_devicestatus))
{
	$file_devicestatus =~ s/.*[^[:print:]]+//;
	print "<prtg><error>1</error><text>Es wurde kein Meraki API-Key und/oder keine Organization-ID und/oder kein Dateiname fuer die Datei mit heruntergeladenen Geraeteinformationen uebergeben. Bitte Parameter in den Sensoreinstellungen setzen: \"<OrgID> <API-Key> <Filename_StatusFile>\"</text></prtg>";
	die;
}
	
	if (-e $lockfilename)
	{
		unlink $lockfilename or $mustdie = 1;
		if ($mustdie)
		{
			print '<prtg><error>1</error><text>Das bestehende Lockfile \"$lockfilename\" konnte nicht geloescht werden</text></prtg>';
			die;
		}
	}
	
	open(my $lockfile, '>', $lockfilename) or $mustdie = 1;
	if ($mustdie) 
	{
		print '<prtg><error>1</error><text>Es konnte kein Lockfile erzeugt werden</text></prtg>';	
		die;
	}
	
	my $browser = LWP::UserAgent->new;
	my $request = HTTP::Request->new(GET => "https://dashboard.meraki.com/api/v0/organizations/$orgid/deviceStatuses");
	$request->content_type('application/json');
	$request->header('X-Cisco-Meraki-API-Key' => $apikey);	
	my $response = $browser->request($request);
	
	if ($response->is_success)
	{		
		my $fh;
		my $handleopen = 0;
		my $retries = 1;
						
		while ($handleopen == 0 && $retries <10)
		{		
			$handleopen = 1;
			open($fh, '>', $file_devicestatus) or $handleopen = 0;
			if ($handleopen == 0)
			{
				$retries++;
				sleep 1;
			}
		}
		
		if ($handleopen == 0)
		{
			close $lockfilename;			
			print "<prtg><error>1</error><text>Die Datei \"$file_devicestatus\" konnte nach $retries Versuchen nicht zum Schreiben geoeffnet werden</text></prtg>";
			unlink $lockfilename;
			die;
		}		
		
		print $fh $response->decoded_content; 
		close $fh;
		
		print "<prtg><result><channel>Download Statusdatei</channel><value>1</value><Unit>Count</Unit><mode>Absolute</mode></result></prtg>";
	} else
	{
		print'<prtg><error>1</error><text>Die Statusdatei konnte nicht vom Meraki Dashboard heruntergeladen werden. HTTP-Fehlercode: '.$response->status_line().'</text></prtg>';
	}
		
close $lockfile;
unlink $lockfilename;









