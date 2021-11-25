//// Variables

// Target account id. Where will DivvyCloud be deployed?
variable "account_id" {
    type        = string
    default     = "643608447313"
    description = " Target account id. Where will DivvyCloud be deployed?"
}

/* variable "access_key" {
    type = string
    default = ""
    description = "access key (varies based on region/az)"
}


// AMI for EC2 Instances (varies based on region/az)
variable "secret_key" {
    type = string
    default = ""
    description = "secret key (varies based on region/az)"
}

variable "session_token" {
    type = string
    default = ""
    description = "token"
}
*/
// AMI for EC2 Instances (varies based on region/az)
variable "ami" {
    type = string
    default = "ami-02908010dba88b00d"
    description = "AMI for EC2 Instances (varies based on region/az)"
}

// Two AZs for redundancy
variable "az" {
    type    = list(string)
    default = ["us-west-2b","us-west-2c"]
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
    default = "v21.3.5"
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
    default = "divvycloud-api-access-dr"
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

// Subnet definitions
variable "private_subnet1_id" {
    type = string
    default = "subnet-0b386fddcedb03e06"
    description = "Private Subnet definitions"
}

variable "private_subnet2_id" {
    type = string
    default = "subnet-0a138a39587d3f7e9"
    description = "Private Subnet ID"
}

variable "data_subnet1_id" {
    type = string
      default = "subnet-01a8063e3e961d118"
    description = "Data Subnet ID"
}

variable "data_subnet2_id" {
    type = string
    default = "subnet-01a29d14e9d220a7d"
    description = "Data Subnet ID"
}

variable "region" {
    type = string
    default = "us-west-2"
    description = "AWS Region in which DivvyCloud will be deployed"
}

variable "ssh_keypair" {
    type    = string
    default = "divvycloud"
    description = "SSH Key Pair for Instances"
}

// Hosted Zone ID for Route53 resource
variable "Hosted-Zone-ID" {
    type = string
    #default = "Z156W5GGHF1VZP"
    default = "Z01365062E6OY3BJ8YT3C"
  description = "Hosted Zone ID for Route53 resource"
}

variable "vpc_id" {
    type = string
    default = "vpc-01a22eeb6a4b873c8"
    description = "VPC ID for Divvy Cloud deployment" 
}

variable "vpc_cidr_block" {
    type = string
    default = "10.234.48.0/21"
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
    default = 14
    description = "Number of Worked Task Count. Best ROI is m5.xlarge running 16 worker processes"
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
      ssl_arn = "arn:aws:acm:us-west-2:643608447313:certificate/89dc5b94-0f01-4867-85cc-7e8a3268695f"
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
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -yq
apt-get install -y awscli
apt-get install -y mysql-client
sudo snap install amazon-ssm-agent --classic
sudo systemctl restart snap.amazon-ssm-agent.amazon-ssm-agent.service
apt install docker.io -y
aws s3api get-object --bucket shared-security-terraform --key docker-compose-Linux-x86_64 /usr/bin/docker-compose
sudo chmod +x /usr/bin/docker-compose
# NEW CODE PART 1
wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb -O /tmp/amazon-cloudwatch-agent.deb
dpkg -i /tmp/amazon-cloudwatch-agent.deb
rm -f /tmp/amazon-cloudwatch-agent.deb
usermod -aG adm cwagent
wget -q https://s3.amazonaws.com/get.divvycloud.com/prodserv/aws/terraform/cw-agent/amazon-cloudwatch-agent.json -O /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
sed -i 's|"region": "us-east-1"|"region": "${var.region}"|g' /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
service amazon-cloudwatch-agent restart
echo export INSTANCE_ID="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)" >> /etc/environment
export INSTANCE_ID="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
# END CODE PART 1
curl -s https://s3.amazonaws.com/get.divvycloud.com/prod.html | bash
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
sed -i 's|scale: 8|scale: ${var.worker_task_count}|g' /divvycloud/docker-compose.yml
sed -i '3,36d' /divvycloud/docker-compose.yml
sed -i 's/divvycloud:latest/divvycloud:${var.divvycloud_version}/g' /divvycloud/docker-compose.yml
/usr/bin/docker-compose -f /divvycloud/docker-compose.yml up -d
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
apt install docker.io -y
aws s3api get-object --bucket shared-security-terraform --key docker-compose-Linux-x86_64 /usr/bin/docker-compose
sudo chmod +x /usr/bin/docker-compose
# NEW CODE PART 1
wget -q https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb -O /tmp/amazon-cloudwatch-agent.deb
dpkg -i /tmp/amazon-cloudwatch-agent.deb
rm -f /tmp/amazon-cloudwatch-agent.deb
usermod -aG adm cwagent
wget -q https://s3.amazonaws.com/get.divvycloud.com/prodserv/aws/terraform/cw-agent/amazon-cloudwatch-agent.json -O /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
sed -i 's|"region": "us-east-1"|"region": "${var.region}"|g' /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
service amazon-cloudwatch-agent restart
echo export INSTANCE_ID="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)" >> /etc/environment
export INSTANCE_ID="$(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
# END CODE PART 1
curl -s https://s3.amazonaws.com/get.divvycloud.com/prod.html | bash
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
sed -i '36,$d' /divvycloud/docker-compose.yml
sed -i 's/divvycloud:latest/divvycloud:${var.divvycloud_version}/g' /divvycloud/docker-compose.yml
/usr/bin/docker-compose -f /divvycloud/docker-compose.yml up -d

EOF
}
