#!/usr/bin/perl
use strict;
use warnings;
use File::Slurp;

#this script polls a local status file generated by 1_meraki_download_device_state.pl for the status of a specific meraki mx device
#this script generates XML output which can be used as a custom XML/EXE sensor in PRTG monitoring software

my $file_devicestatus = $ARGV[0]; #takes the name of the local file to poll as first parameter
my $device_serial = $ARGV[1]; #takes the device serial of the mx as second parameter
my $lockfilename = 'downloading.lock'; #name of the lockfile to look for. if it exists, the script wairts until its gone and then polls the local status file. the script waits for a maximum of 5 seconds before polling the current (old) local file
my $lockwaits = 1; 

if (!defined($file_devicestatus) || !defined($device_serial))
{
	$file_devicestatus =~ s/.*[^[:print:]]+//;
	print "<prtg><error>1</error><text>Es wurde keine Geraete-Seriennummer und/oder Dateiname angegeben, aus welchem der Geraetestatus gelesen werden soll. Bitte Sensoreinstellungen ueberpruefen. Parameter: <Statusdatei> <Geraeteserial></text></prtg>";
	die;
}
	
while (-e $lockfilename && $lockwaits < 5)
{
		
	$lockwaits++;
	sleep 1;	
}						

if (-e $lockfilename)
{
	print "<prtg><error>1</error><text>Die lokale Statusdatei \"$file_devicestatus\" konnte auch nach $lockwaits Versuchen nicht gelesen werden, da sie gesperrt ist</text></prtg>";
	die;
}

my $mustdie = 0;
my $dvc_status = read_file($file_devicestatus) or $mustdie = 1;
if ($mustdie)
{
	print "<prtg><error>1</error><text>Die lokale Statusdatei \"$file_devicestatus\" konnte nicht zum Lesen geoeffnet werden</text></prtg>";
	die;
}

if ($dvc_status =~ /(\{[^{}]*?$device_serial.*?\})/mi)
{
	$dvc_status = $1;
	my $device_onlinestate = 'false';
	my $device_cellfailover = '0';
	my $networkid = 'n/a';
	my $public_ip_used = 'n/a';
	my $wan1ip = 'n/a';
	my $wan2ip = 'n/a';
	
	if ($dvc_status =~ /\"status\":\s*\"(.*?)\"/mi)
	{
		$device_onlinestate = $1;		
	}
	
	if ($dvc_status eq '')
	{
		die "<prtg><error>1</error><text>Geraetestatus konnte nicht aus Datei \"$file_devicestatus\" ermittelt werden</text></prtg>";
	}
	
	if ($dvc_status =~ /\"usingCellularFailover\":\s*(.*?),/mi)
	{
		$device_cellfailover = $1;
	}	
	
	if ($dvc_status =~ /\"networkId\":\s*\"(.*?)\"/mi)
	{
		$networkid = $1;		
	}

	if ($dvc_status =~ /\"publicIp\":\s*\"(.*?)\"/mi)
	{
		$public_ip_used = $1;		
	}
	
	if ($dvc_status =~ /\"wan1Ip\":\s*?(\")?(.+?)(\")?[,}]/mi)
	{
		$wan1ip = $2;				
	}
	
	if ($dvc_status =~ /\"wan1Ip\":\s*?(\")?(.+?)(\")?[,}]/mi)
	{
		$wan2ip = $2;				
	}	

	if ($device_onlinestate eq 'online')
	{
		if ($device_cellfailover eq 'true')
		{
			#geraet online aber cellullar failover
			print "<prtg><result><channel>Onlinestatus</channel><value>1</value><Unit>Count</Unit><mode>Absolute</mode><warning>1</warning></result><text>Mobilfunk-Failover ist aktiv! NetworkID: $networkid, oeffentliche IP in Benutzung: $public_ip_used, WAN1-IP: $wan1ip, WAN2-IP: $wan2ip</text></prtg>";
		} else
		{
			#alles ok mit dem teil
			print "<prtg><result><channel>Onlinestatus</channel><value>1</value><Unit>Count</Unit><mode>Absolute</mode></result><text>NetworkID: $networkid, oeffentliche IP in Benutzung: $public_ip_used, WAN1-IP: $wan1ip, WAN2-IP: $wan2ip</text></prtg>";
		}
	} else
	{
		#geraet meldet nicht online
		print "<prtg><error>1</error><result><channel>Onlinestatus</channel><value>0</value><Unit>Count</Unit><mode>Absolute</mode></result><text>Das Geraet meldet einen Fehlerstatus: $device_onlinestate</text></prtg>";
	}
	
} else
{
	print "<prtg><error>1</error><text>Das Geraet mit der Seriennummer $device_serial wurde in der Statusdatei nicht gefunden</text></prtg>";
	die;
}







