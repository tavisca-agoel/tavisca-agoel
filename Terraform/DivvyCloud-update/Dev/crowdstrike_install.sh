#!/bin/bash

set -o pipefail
set -o errexit
set -o nounset

#Author				: Mohit Kunjir
#Email-ID			: mkunjir@tavisca.com
#Date of Creation	: 24th March 2021
#Purpose			: To automate the crowdstrike installation on divvycloud instances

cd /tmp


#Fetch crowdstrike artifacts
aws s3api get-object --bucket cxloyalty-application-artifacts --key artifacts/crowdstrike/crowdstrike.tar.gz /tmp/crowdstrike.tar.gz

#Unpacking the packages archive and moving to the directory
tar -xzvf crowdstrike.tar.gz && cd crowdstrike/

crowdstrike_customer_id_checksum=`cat CustomerID-Checksum.txt`
crowdstrike_grouping_tag=`cat Crowdstrike-Tag.txt`

#Adding Execute permissions
chmod +x Linux/greenjuice7055_FFCNix_2021_01_11.run

if !(type lsb_release &>/dev/null); then
	distribution=$(cat /etc/*-release | grep '^NAME' );
	release=$(cat /etc/*-release | grep '^VERSION_ID');
else
	distribution=$(lsb_release -i | grep 'ID' | grep -v 'n/a');
	release=$(lsb_release -r | grep 'Release' | grep -v 'n/a');
fi;
if [ -z "$distribution" ]; then
	distribution=$(cat /etc/*-release);
	release=$(cat /etc/*-release);
fi;

releaseVersion=${release//[!0-9.]};
case $distribution in
	*"Debian"*)
		sudo dpkg -i Linux/Debian/falcon-sensor_6.12.0-10912_amd64.deb || true
		sudo apt-get install -fy
		sudo /opt/CrowdStrike/falconctl -s -f --cid=$crowdstrike_customer_id_checksum --tags=$crowdstrike_grouping_tag
		sudo systemctl start falcon-sensor.service
		sudo systemctl enable falcon-sensor.service		
		sudo Linux/greenjuice7055_FFCNix_2021_01_11.run --keep >> /var/log/crowdstrike.log
		;;
	*"Ubuntu"*)
		sudo dpkg -i Linux/Ubuntu/falcon-sensor_6.12.0-10912_amd64.deb || true
		sudo apt-get install -fy
		sudo /opt/CrowdStrike/falconctl -s -f --cid=$crowdstrike_customer_id_checksum --tags=$crowdstrike_grouping_tag
		sudo systemctl start falcon-sensor.service
		sudo systemctl enable falcon-sensor.service		
		sudo Linux/greenjuice7055_FFCNix_2021_01_11.run --keep >> /var/log/crowdstrike.log
		;;
	*"SUSE"* | *"SLES"*)
		if [[ $releaseVersion =~ ^11.* ]]; then
			sudo zypper install -y Linux/SUSE/falcon-sensor-6.12.0-10912.suse11.x86_64.rpm
			sudo /opt/CrowdStrike/falconctl -s -f --cid=$crowdstrike_customer_id_checksum --tags=$crowdstrike_grouping_tag
			sudo Linux/greenjuice7055_FFCNix_2021_01_11.run --keep >> /var/log/crowdstrike.log
		elif [[ $releaseVersion =~ ^12.* ]]; then
			sudo zypper install -y Linux/SUSE/falcon-sensor-6.12.0-10912.suse12.x86_64.rpm
			sudo /opt/CrowdStrike/falconctl -s -f --cid=$crowdstrike_customer_id_checksum --tags=$crowdstrike_grouping_tag
			sudo Linux/greenjuice7055_FFCNix_2021_01_11.run --keep >> /var/log/crowdstrike.log
		elif [[ $releaseVersion =~ ^15.* ]]; then
			sudo zypper install -y Linux/SUSE/falcon-sensor-6.12.0-10912.suse15.x86_64.rpm
			sudo /opt/CrowdStrike/falconctl -s -f --cid=$crowdstrike_customer_id_checksum --tags=$crowdstrike_grouping_tag
			sudo Linux/greenjuice7055_FFCNix_2021_01_11.run --keep >> /var/log/crowdstrike.log
		fi;
		;;
	*"Oracle"* | *"CentOS"* | *"RedHat"* | *"Red Hat"*)
		if [[ $releaseVersion =~ ^6.* ]]; then
			sudo yum localinstall -y Linux/RHEL-CENTOS-ORACLE/falcon-sensor-6.12.0-10912.el6.x86_64.rpm
			sudo /opt/CrowdStrike/falconctl -s -f --cid=$crowdstrike_customer_id_checksum --tags=$crowdstrike_grouping_tag
			sudo Linux/greenjuice7055_FFCNix_2021_01_11.run --keep >> /var/log/crowdstrike.log
		elif [[ $releaseVersion =~ ^7.* ]]; then
			sudo yum localinstall -y Linux/RHEL-CENTOS-ORACLE/falcon-sensor-6.12.0-10912.el7.x86_64.rpm
			sudo /opt/CrowdStrike/falconctl -s -f --cid=$crowdstrike_customer_id_checksum --tags=$crowdstrike_grouping_tag
			sudo Linux/greenjuice7055_FFCNix_2021_01_11.run --keep >> /var/log/crowdstrike.log
		elif [[ $releaseVersion =~ ^8.* ]]; then
			sudo yum localinstall -y Linux/RHEL-CENTOS-ORACLE/falcon-sensor-6.12.0-10912.el8.x86_64.rpm
			sudo /opt/CrowdStrike/falconctl -s -f --cid=$crowdstrike_customer_id_checksum --tags=$crowdstrike_grouping_tag
			sudo Linux/greenjuice7055_FFCNix_2021_01_11.run --keep >> /var/log/crowdstrike.log
		fi;                                                 
		;;
	*"Amazon"*)	
		if [[ $(uname -r) == *"amzn2"* ]]; then
			sudo yum localinstall -y Linux/AmazonLinux/falcon-sensor-6.12.0-10912.amzn2.x86_64.rpm
			sudo /opt/CrowdStrike/falconctl -s -f --cid=$crowdstrike_customer_id_checksum --tags=$crowdstrike_grouping_tag
			sudo service falcon-sensor restart
			sudo Linux/greenjuice7055_FFCNix_2021_01_11.run --keep >> /var/log/crowdstrike.log
			
		elif [[ $(uname -r) == *"amzn1"* ]]; then
			sudo yum localinstall -y Linux/AmazonLinux/falcon-sensor-6.12.0-10912.amzn1.x86_64.rpm
			sudo /opt/CrowdStrike/falconctl -s -f --cid=$crowdstrike_customer_id_checksum --tags=$crowdstrike_grouping_tag
			sudo service falcon-sensor restart
			sudo Linux/greenjuice7055_FFCNix_2021_01_11.run --keep >> /var/log/crowdstrike.log			
		fi;
		;;
esac
#Display result
if [ $? -eq 0 ]
then
	rm -rf /tmp/crowdstrike*
	echo "========================================"
	echo "CrowdStrike scan status"
	echo "========================================"
	cat /var/log/crowdstrike.log
	echo "========================================"
	echo "CrowdStrike falcon.service status"
	echo "========================================"
	ps -ef | grep falcon-sensor
	echo ""
	echo "CrowdStrike Installation & One-time Scan Completed!!"
else
	echo "Aborting the crowdstrike.zip and folder deletion. Please check the installation manually"
	exit 1
fi
##End of the Script##