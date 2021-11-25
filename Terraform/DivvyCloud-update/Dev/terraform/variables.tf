//// Variables

// Target account id. Where will DivvyCloud be deployed?
variable "account_id" {
    type        = string
    default     = "982267650803"
    description = " Target account id. Where will DivvyCloud be deployed?"
}

// AMI for EC2 Instances (varies based on region/az)
variable "ami" {
    type = string
    default = "ami-0aa28de3a22331d5c"
    description = "AMI for EC2 Instances (varies based on region/az)"
}

// Two AZs for redundancy
variable "az" {
    type    = list(string)
    default = ["us-east-1b","us-east-1c"]
    description = "Two AZs for redundancy"
}

/*
// Set root user/pass for RDS instance (also used by DivvyCloud)
variable "database_credentials" {
    type    = list(string)
    default = ["divvy","divvycloud"]
    description = "Set root user/pass for RDS instance (also used by DivvyCloud)"
}
*/

// Length of RDS password
variable "divvycloud_random" {
    type    = number
    default = 20
    description = "Length of RDS password"
}

// RDS master user
variable "database_username" {
    type    = string
    default = "divvy"
    description = "RDS Database Username"
}

variable "secret_dbname" {
    type = string
    default = "divvykeys"
    description = "RDS Database Name"
}

variable "divvycloud_version" {
    type = string
    default = "v21.1.5"
    description = "DivvyCloud Version"
}

variable "aws_log_group_name" {
    type = string
    default = "DivvyCloud-EC2"
    description = "Name of the AWS Log Group"
}

// Allow outbound access (does not apply to IGW)
variable "egress_whitelist" {
    type    = list(string)
    default = ["0.0.0.0/0"]
    description = " Allow outbound access (does not apply to IGW)"
}

// Allow outbound access
variable "iam_instance_profile" {
    type    = string
    default = "dvcloud-api-access"
    description = "Allow outbound access"
}

// Allow SSH access to EC2 instances via this range.
// See "security group SSH rule" entries below
variable "ingress_ssh_whitelist" {
    type    = list(string)
    default = ["172.20.0.0/15", "10.64.64.0/19", "10.64.64.0/18"]
    description = "Allow SSH access to EC2 instances via this range."
}

// Allow access to the ALB (UI) via these IP address(es)
variable "ingress_whitelist" {
    type    = list(string)
    //Slough, Plano, VPN, Westerville, Stamford, Pune NATd, Manilla, Eden Prairie
    default = ["10.247.172.0/25", "172.21.64.0/24", "10.64.64.0/18", "172.21.92.0/23", "172.21.96.0/23", "115.112.37.252/32", "172.21.247.0/24", "172.21.176.0/24"]
    description = "Allow access to the ALB (UI) via these IP address(es)"
}

// Security Group
variable "Bypass-SG" {
    type = string
    default = "sg-0a85e69b678f36db0"
    description = "By Pass SG"
}

// Subnet definitions
variable "private_subnet1_id" {
    type = string
    default = "subnet-091141ba0045fd49d"
    description = "Private Subnet definitions"
}

variable "private_subnet2_id" {
    type = string
    default = "subnet-0751f5ebf7ae524fe"
    description = "Private Subnet ID"
}

variable "data_subnet1_id" {
    type = string
      default = "subnet-0777d956863356974"
    description = "Data Subnet ID"
}

variable "data_subnet2_id" {
    type = string
    default = "subnet-039d5739ca4253181"
    description = "Data Subnet ID"
}

variable "region" {
    type = string
    default = "us-east-1"
    description = "AWS Region in which DivvyCloud will be deployed"
}

variable "ssh_keypair" {
    type    = string
    default = "divvycloud-dev"
    description = "SSH Key Pair for Instances"
}

// Hosted Zone ID for Route53 resource
variable "Hosted-Zone-ID" {
    type = string
    #default = "Z156W5GGHF1VZP"
    default = "ZCSO3HENW30GG"
  description = "Hosted Zone ID for Route53 resource"
}

variable "vpc_id" {
    type = string
    default = "vpc-0687380e5e42ff7cc"
    description = "VPC ID for Divvy Cloud deployment" 
}

variable "vpc_cidr_block" {
    type = string
    default = "10.234.112.0/22"
    description = "VPC CIDR Block"
}

// Even number only
variable "worker_instance_count" {
    type = number
    default = 4
    description = "Number of DivvyCLoud Worker Instances. (Even number only)"
}

// Best ROI is m5.xlarge running 16 worker processes
variable "worker_task_count" {
    type = number
    default = 4
    description = "Number of Worker Task Count. Best ROI is m5.xlarge running 16 worker processes"
}

//// Locals
// Define data for Secrets Manager
locals {
    dbsecret_json = {
        default = {
            engine = aws_db_instance.DivvyCloud-MySQL.engine
            host = aws_db_instance.DivvyCloud-MySQL.address
            username = var.database_username
            password = "${random_string.DivvyCloud-Random.result}"
            dbInstanceIdentifier = aws_db_instance.DivvyCloud-MySQL.identifier
            dbname = aws_db_instance.DivvyCloud-MySQL.name
            port = aws_db_instance.DivvyCloud-MySQL.port
            //ssh_priv = tls_private_key.DivvyCloud-EC2-SSH-Private-Key.private_key_pem
            secret_dbname = var.secret_dbname
        }
        type = "map"
    }
}

// SSL Certificate for ALB
locals {
      ssl_arn = "arn:aws:acm:us-east-1:982267650803:certificate/60eedd6c-01fc-4f5d-9794-e5ccd091143b"
}

// Timestamp for the final snapshot of the MySQL DB
locals {
  timestamp = formatdate("YYYYMMDDhhmmss", timestamp())
}

// EC2 Worker user data
locals {
   worker_user_data = <<EOF
#!/bin/bash -xe
apt-get update

# remove old ntp
sudo apt remove ntp* -y
# download chrony and start it
sudo apt install chrony -y
sudo echo 'server 169.254.169.123 prefer iburst minpoll 4 maxpoll 4' > /etc/chrony/chrony.conf
sudo /etc/init.d/chrony restart
sudo systemctl enable chrony.service
chronyc sources -v
chronyc tracking
DEBIAN_FRONTEND=noninteractive apt-get upgrade -yq
apt-get install -y awscli
apt-get install -y mysql-client
sudo snap install amazon-ssm-agent --classic
sudo systemctl restart snap.amazon-ssm-agent.amazon-ssm-agent.service
# NEW CODE PART 1
wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb -O /tmp/amazon-cloudwatch-agent.deb
dpkg -i /tmp/amazon-cloudwatch-agent.deb
rm -f /tmp/amazon-cloudwatch-agent.deb
usermod -aG adm cwagent
aws s3api get-object --bucket cxloyalty-divvycloud-artifacts --key amazon-cloudwatch-agent.json /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
sed -i 's|"region": "us-east-1"|"region": "${var.region}"|g' /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
service amazon-cloudwatch-agent restart
echo export INSTANCE_ID="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)" >> /etc/environment
export INSTANCE_ID="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
# END CODE PART 1
aws s3api get-object --bucket cxloyalty-divvycloud-artifacts --key prod.html /home/ubuntu/prod.html
bash /home/ubuntu/prod.html
# NEW CODE PART 2
wget -q https://s3.amazonaws.com/get.divvycloud.com/compose/daemon-cw.json -O /etc/docker/daemon.json
sed -i 's|"awslogs-region": "us-east-1"|"awslogs-region": "${var.region}"|g' /etc/docker/daemon.json
sed -i 's|DivvyCloud-EC2|${var.aws_log_group_name}|g' /etc/docker/daemon.json
systemctl restart docker
# END CODE PART 2
sed -i '2 i REGION=${var.region}' /divvycloud/prod.env
sed -i '1 i DIVVY_SECRETS_PROVIDER_CONFIG=AWSAssumeRole,region=${var.region},secret_name=${aws_secretsmanager_secret.divvycloud-credentials.name}' /divvycloud/prod.env
sed -i '/DIVVY_DB_USERNAME\|DIVVY_DB_PASSWORD\|DIVVY_DB_HOST\|DIVVY_DB_PORT/ d' /divvycloud/prod.env
sed -i '/DIVVY_SECRET_DB_HOST\|DIVVY_SECRET_DB_PORT\|DIVVY_SECRET_DB_USERNAME\|DIVVY_SECRET_DB_PASSWORD/ d' /divvycloud/prod.env
sed -i 's|DIVVY_REDIS_HOST=redis|DIVVY_REDIS_HOST=${aws_elasticache_cluster.DivvyCloud-Redis.cache_nodes.0.address}|g' /divvycloud/prod.env
sed -i 's|scale: 8|scale: ${var.worker_task_count}|g' /divvycloud/docker-compose.cw.yml
sed -i '3,48d' /divvycloud/docker-compose.cw.yml
sed -i 's/divvycloud:latest/divvycloud:${var.divvycloud_version}/g' /divvycloud/docker-compose.cw.yml
/usr/local/bin/docker-compose -f /divvycloud/docker-compose.cw.yml up -d
# Crowdstrike Installation
aws s3api get-object --bucket cxloyalty-application-artifacts --key artifacts/crowdstrike/crowdstrike_install_divvycloud.sh /tmp/crowdstrike_install_divvycloud.sh
chmod +x /tmp/crowdstrike_install_divvycloud.sh
sudo /tmp/crowdstrike_install_divvycloud.sh
chmod 755 /etc/cron.weekly/remove-docker-images
EOF
}

// EC2 UI/Scheduler user data
locals {
   ui_sched_user_data = <<EOF
#!/bin/bash -xe
apt-get update
# remove old ntp
sudo apt remove ntp* -y
# download chrony and start it
sudo apt install chrony -y
sudo echo 'server 169.254.169.123 prefer iburst minpoll 4 maxpoll 4' > /etc/chrony/chrony.conf
sudo /etc/init.d/chrony restart
sudo systemctl enable chrony.service
chronyc sources -v
chronyc tracking
DEBIAN_FRONTEND=noninteractive apt-get upgrade -yq
apt-get install -y mysql-client
apt-get install -y awscli
sudo snap install amazon-ssm-agent --classic
sudo systemctl restart snap.amazon-ssm-agent.amazon-ssm-agent.service
# NEW CODE PART 1
wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb -O /tmp/amazon-cloudwatch-agent.deb
dpkg -i /tmp/amazon-cloudwatch-agent.deb
rm -f /tmp/amazon-cloudwatch-agent.deb
usermod -aG adm cwagent
aws s3api get-object --bucket cxloyalty-divvycloud-artifacts --key amazon-cloudwatch-agent.json /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
sed -i 's|"region": "us-east-1"|"region": "${var.region}"|g' /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
service amazon-cloudwatch-agent restart
echo export INSTANCE_ID="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)" >> /etc/environment
export INSTANCE_ID="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
# END CODE PART 1
aws s3api get-object --bucket cxloyalty-divvycloud-artifacts --key prod.html /home/ubuntu/prod.html
bash /home/ubuntu/prod.html
# NEW CODE PART 2
wget -q https://s3.amazonaws.com/get.divvycloud.com/compose/daemon-cw.json -O /etc/docker/daemon.json
sed -i 's|"awslogs-region": "us-east-1"|"awslogs-region": "${var.region}"|g' /etc/docker/daemon.json
sed -i 's|DivvyCloud-EC2|${var.aws_log_group_name}|g' /etc/docker/daemon.json
systemctl restart docker
# END CODE PART 2
sed -i '2 i REGION=${var.region}' /divvycloud/prod.env
sed -i '1 i DIVVY_SECRETS_PROVIDER_CONFIG=AWSAssumeRole,region=${var.region},secret_name=${aws_secretsmanager_secret.divvycloud-credentials.name}' /divvycloud/prod.env
sed -i '/DIVVY_DB_USERNAME\|DIVVY_DB_PASSWORD\|DIVVY_DB_HOST\|DIVVY_DB_PORT/ d' /divvycloud/prod.env
sed -i '/DIVVY_SECRET_DB_HOST\|DIVVY_SECRET_DB_PORT\|DIVVY_SECRET_DB_USERNAME\|DIVVY_SECRET_DB_PASSWORD/ d' /divvycloud/prod.env
sed -i 's|DIVVY_REDIS_HOST=redis|DIVVY_REDIS_HOST=${aws_elasticache_cluster.DivvyCloud-Redis.cache_nodes.0.address}|g' /divvycloud/prod.env
sed -i '48,$d' /divvycloud/docker-compose.cw.yml
sed -i 's/divvycloud:latest/divvycloud:${var.divvycloud_version}/g' /divvycloud/docker-compose.cw.yml
/usr/local/bin/docker-compose -f /divvycloud/docker-compose.cw.yml up -d
# Crowdstrike Installation
aws s3api get-object --bucket cxloyalty-application-artifacts --key artifacts/crowdstrike/crowdstrike_install_divvycloud.sh /tmp/crowdstrike_install_divvycloud.sh
chmod +x /tmp/crowdstrike_install_divvycloud.sh
sudo /tmp/crowdstrike_install_divvycloud.sh
chmod 755 /etc/cron.weekly/remove-docker-images
EOF
}
