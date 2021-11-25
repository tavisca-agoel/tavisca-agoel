/*
AWS Standard Deployment (EC2/Docker/MySQL/ELB)
Author: Brendan Elliott
Date:   12/16/19
Modified By: Mohit Kunjir
Modified Date: 16-09-2020
Ver:    1.1
*/

// Provider Info
provider "aws" {
    region     = "us-east-1"
}


//// Resources

// Random string generator
resource "random_string" "DivvyCloud-Random-Short" {
  length = 6
  special = false
  number = false
  upper = false
}

// Random password generator for RDS
resource "random_string" "DivvyCloud-Random" {
  length = var.divvycloud_random
  special = true
  override_special = "!-_=+[]{}:?" 
  number = true
  upper = true
}

resource "aws_secretsmanager_secret" "divvycloud-credentials" {
    name = "divvycloud-credentials-${random_string.DivvyCloud-Random-Short.result}"
    tags = {
      Name = "DivvyCloud-Credentials"
      Purpose = "Business"
      Product = "DivvyCloud"
      ProductOwner = "cia_security@tavisca.com"
      BusinessUnit = "Security"
      Environment = "Dev"
    }
}


resource "aws_secretsmanager_secret_version" "divvycloud-credentials" {
  secret_id     = aws_secretsmanager_secret.divvycloud-credentials.id
  secret_string = jsonencode(local.dbsecret_json.default)
}


/// ElastiCache Stack

// Redis security group
resource "aws_security_group" "DivvyCloud-SecurityGroup-Redis" {
    description = "RedisAccess"
    name        = "DivvyCloud-SecurityGroup-Redis"
    vpc_id      =  var.vpc_id
    tags = {
      Name = "DivvyCloud-SecurityGroup-Redis"
      Purpose = "Business"
      Product = "DivvyCloud"
      ProductOwner = "cia_security@tavisca.com"
      BusinessUnit = "Security"
      Environment = "Dev"
    }
}

// Redis security group ingress rule
resource "aws_security_group_rule" "DivvyCloud-SecurityGroup-Redis" {
    cidr_blocks       = [var.vpc_cidr_block]
    from_port         = 6379
    ipv6_cidr_blocks  = []
    prefix_list_ids   = []
    protocol          = "tcp"
    security_group_id = aws_security_group.DivvyCloud-SecurityGroup-Redis.id
    self              = false
    to_port           = 6379
    type              = "ingress"

}

// Redis security group egress rule
resource "aws_security_group_rule" "DivvyCloud-SecurityGroup-Redis2" {
    cidr_blocks       = var.egress_whitelist
    from_port         = 0
    ipv6_cidr_blocks  = []
    prefix_list_ids   = []
    protocol          = "-1"
    security_group_id = aws_security_group.DivvyCloud-SecurityGroup-Redis.id
    self              = false
    to_port           = 0
    type              = "egress"
}

// Redis Subnet Group
resource "aws_elasticache_subnet_group" "DivvyCloud-Redis-Subnet-Group" {
  name       = "divvycloud-redis-subnet-group"
  subnet_ids = [var.data_subnet1_id, var.data_subnet2_id]
}

// Redis Cluster
resource "aws_elasticache_cluster" "DivvyCloud-Redis" {
    availability_zone        = var.az[0]
    az_mode                  = "single-az"
    cluster_id               = "divvycloud-redis"
    engine                   = "redis"
    engine_version           = "4.0.10"
    maintenance_window       = "fri:08:00-fri:09:00"
    node_type                = "cache.t3.micro"
    num_cache_nodes          = 1
    parameter_group_name     = "default.redis4.0"
    port                     = 6379
    security_group_ids       = [aws_security_group.DivvyCloud-SecurityGroup-Redis.id]
    security_group_names     = []
    snapshot_retention_limit = 0
    snapshot_window          = "04:00-05:00"
    subnet_group_name        = aws_elasticache_subnet_group.DivvyCloud-Redis-Subnet-Group.id
    tags                     = {
      Name = "DivvyCloud-Redis"
      Purpose = "Business"
      Product = "DivvyCloud"
      ProductOwner = "cia_security@tavisca.com"
      BusinessUnit = "Security"
      Environment = "Dev"
    }
}


/// RDS Stack

// MySQL security group
resource "aws_security_group" "DivvyCloud-SecurityGroup-RDS" {
    description = "Database Rules"
    name        = "DivvyCloud-SecurityGroup-RDS"
    vpc_id      =  var.vpc_id
    tags = {
      Name = "DivvyCloud-SecurityGroup-RDS-SG"
      Purpose = "Business"
      Product = "DivvyCloud"
      ProductOwner = "cia_security@tavisca.com"
      BusinessUnit = "Security"
      Environment = "Dev"
    }
}

// MySQL security group  ingress rule
resource "aws_security_group_rule" "DivvyCloud-SecurityGroup-RDS" {
    cidr_blocks       = [var.vpc_cidr_block]
    from_port         = 3306
    ipv6_cidr_blocks  = []
    prefix_list_ids   = []
    protocol          = "tcp"
    security_group_id = aws_security_group.DivvyCloud-SecurityGroup-RDS.id
    self              = false
    to_port           = 3306
    type              = "ingress"
}

// MySQL security group egress rule
resource "aws_security_group_rule" "DivvyCloud-SecurityGroup-RDS2" {
    cidr_blocks       = var.egress_whitelist
    from_port         = 0
    ipv6_cidr_blocks  = []
    prefix_list_ids   = []
    protocol          = "-1"
    security_group_id = aws_security_group.DivvyCloud-SecurityGroup-RDS.id
    self              = false
    to_port           = 0
    type              = "egress"
}

// MySQL Subnet Group
resource "aws_db_subnet_group" "DivvyCloud-MySQL-Subnet-Group" {
  name       = "divvycloud-mysql-subnet-group"
  subnet_ids = [var.data_subnet1_id, var.data_subnet2_id]
  tags = {
    Name = "DivvyCloud-MySQL-Subnet-Group"
    Purpose = "Business"
    Product = "DivvyCloud"
    ProductOwner = "cia_security@tavisca.com"
    BusinessUnit = "Security"
    Environment = "Dev"
  }
}

// MySQL DB Instance
resource "aws_db_instance" "DivvyCloud-MySQL" {
    allocated_storage                     = 10
    auto_minor_version_upgrade            = true
    backup_retention_period               = 1
    backup_window                         = "09:52-10:22"
    copy_tags_to_snapshot                 = true
    db_subnet_group_name                  = aws_db_subnet_group.DivvyCloud-MySQL-Subnet-Group.id
    deletion_protection                   = false
    enabled_cloudwatch_logs_exports       = ["audit","error","slowquery"]
    engine                                = "mysql"
    engine_version                        = "5.7.33"
    // Comment out final_snapshot_identifier to avoid a modification every apply
    //final_snapshot_identifier             = "divvycloud-mysql-final-${local.timestamp}"
    iam_database_authentication_enabled   = false
    identifier                            = "divvycloud-mysql"
    instance_class                        = "db.t3.micro"
    license_model                         = "general-public-license"
    maintenance_window                    = "wed:04:37-wed:05:07"
    max_allocated_storage                 = 0
    monitoring_interval                   = 0
    //monitoring_role_arn                   = "arn:aws:iam::633297734070:role/DivvyCloud-RDS-Monitoring-Role"
    multi_az                              = false
    name                                  = "divvy"
    option_group_name                     = "default:mysql-5-7"
    parameter_group_name                  = "default.mysql5.7"
    //password                            =  var.database_credentials[1]
    password                              = random_string.DivvyCloud-Random.result
    performance_insights_enabled          = false
    port                                  = 3306
    publicly_accessible                   = false
    security_group_names                  = []
    skip_final_snapshot                   = false
    storage_encrypted                     = true
    storage_type                          = "gp2"
    tags                                  = {
        Name = "DivvyCloud-MySQL"
        Purpose = "Business"
        Product = "DivvyCloud"
        ProductOwner = "cia_security@tavisca.com"
        BusinessUnit = "Security"
        Environment = "Dev"
    }
    //username                              = var.database_credentials[0]
    username                              = var.database_username
    vpc_security_group_ids                = [aws_security_group.DivvyCloud-SecurityGroup-RDS.id]

}


/// EC2 Stack

// EC2/UI-Scheduler security group
resource "aws_security_group" "DivvyCloud-SecurityGroup-UI-Sched" {
    description = "Scheduler/UI rules"
    name        = "DivvyCloud-SecurityGroup-UI"
    vpc_id      = var.vpc_id
    tags = {
      Name = "DivvyCloud-SecurityGroup-UI-Sched-SG"
      Purpose = "Business"
      Product = "DivvyCloud"
      ProductOwner = "cia_security@tavisca.com"
      BusinessUnit = "Security"
      Environment = "Dev"
    }
}

// EC2/UI-Scheduler security group UI rule
resource "aws_security_group_rule" "DivvyCloud-SecurityGroup-UI-Sched" {
    cidr_blocks       = [var.vpc_cidr_block]
    from_port         = 8001
    ipv6_cidr_blocks  = []
    prefix_list_ids   = []
    protocol          = "tcp"
    security_group_id = aws_security_group.DivvyCloud-SecurityGroup-UI-Sched.id
    self              = false
    to_port           = 8001
    type              = "ingress"
}

// EC2/UI-Scheduler security group egress rule
resource "aws_security_group_rule" "DivvyCloud-SecurityGroup-UI-Sched2" {
    cidr_blocks       = var.egress_whitelist
    from_port         = 0
    ipv6_cidr_blocks  = []
    prefix_list_ids   = []
    protocol          = "-1"
    security_group_id = aws_security_group.DivvyCloud-SecurityGroup-UI-Sched.id
    self              = false
    to_port           = 0
    type              = "egress"
}

// EC2/Worker security group
resource "aws_security_group" "DivvyCloud-SecurityGroup-Worker" {
    description = "Worker rules"
    name        = "DivvyCloud-SecurityGroup-Worker"
    vpc_id      = var.vpc_id
    tags = {
      Name = "DivvyCloud-SecurityGroup-Worker-SG"
      Purpose = "Business"
      Product = "DivvyCloud"
      ProductOwner = "cia_security@tavisca.com"
      BusinessUnit = "Security"
      Environment = "Dev"
    }
}

// EC2/Worker security group SSH rule
resource "aws_security_group_rule" "DivvyCloud-SecurityGroup-Worker" {
    cidr_blocks       = var.ingress_ssh_whitelist
    from_port         = 22
    ipv6_cidr_blocks  = []
    prefix_list_ids   = []
    protocol          = "tcp"
    security_group_id = aws_security_group.DivvyCloud-SecurityGroup-Worker.id
    self              = false
    to_port           = 22
    type              = "ingress"
}

// EC2/Worker security group egress rule
resource "aws_security_group_rule" "DivvyCloud-SecurityGroup-Worker2" {
    cidr_blocks       = var.egress_whitelist
    from_port         = 0
    ipv6_cidr_blocks  = []
    prefix_list_ids   = []
    protocol          = "-1"
    security_group_id = aws_security_group.DivvyCloud-SecurityGroup-Worker.id
    self              = false
    to_port           = 0
    type              = "egress"
}

// EC2/Workers - Group 1
resource "aws_instance" "DivvyCloud-EC2-Worker-AZ1" {
    ami                          = var.ami
    associate_public_ip_address  = false
    count                        = 1
    disable_api_termination      = false
    ebs_optimized                = true
    get_password_data            = false
    iam_instance_profile         = var.iam_instance_profile
    instance_type                = "t3.medium"
    ipv6_address_count           = 0
    ipv6_addresses               = []
    key_name                     = var.ssh_keypair
    monitoring                   = true
    security_groups              = []
    source_dest_check            = true
    subnet_id                    = var.private_subnet1_id
    tags                         = {
        Name = "DivvyCloud-Worker-${count.index}"
		    Purpose = "Business"
        Product = "DivvyCloud"
        ProductOwner = "cia_security@tavisca.com"
        BusinessUnit = "Security"
        Environment = "Dev"
    }
    tenancy                      = "default"
    user_data_base64             = base64encode(local.worker_user_data)
    volume_tags                  = {
        Name = "DivvyCloud-Worker-${count.index}"
		    Purpose = "Business"
        Product = "DivvyCloud"
        ProductOwner = "cia_security@tavisca.com"
        BusinessUnit = "Security"
        Environment = "Dev"
    }
    vpc_security_group_ids       = [aws_security_group.DivvyCloud-SecurityGroup-Worker.id, var.Bypass-SG]

    root_block_device {
        delete_on_termination = true
        encrypted             = true
        volume_size           = 50
        volume_type           = "gp2"
    }
}

// EC2/Workers - Group 2
resource "aws_instance" "DivvyCloud-EC2-Worker-AZ2" {
    ami                          = var.ami
    associate_public_ip_address  = false
    count                        = 1
    disable_api_termination      = false
    ebs_optimized                = true
    get_password_data            = false
    iam_instance_profile         = var.iam_instance_profile
    instance_type                = "t3.medium"
    ipv6_address_count           = 0
    ipv6_addresses               = []
    key_name                     = var.ssh_keypair
    monitoring                   = true
    security_groups              = []
    source_dest_check            = true
    subnet_id                    = var.private_subnet2_id
    tags                         = {
      Name = "DivvyCloud-Worker-${count.index + 1}"
		  Purpose = "Business"
      Product = "DivvyCloud"
      ProductOwner = "cia_security@tavisca.com"
      BusinessUnit = "Security"
      Environment = "Dev"
    }
    tenancy                      = "default"
    user_data_base64             = base64encode(local.worker_user_data)
    volume_tags                  = {
      Name = "DivvyCloud-Worker-${count.index + 1}"
		  Purpose = "Business"
      Product = "DivvyCloud"
      ProductOwner = "cia_security@tavisca.com"
      BusinessUnit = "Security"
      Environment = "Dev"
    }
    vpc_security_group_ids       = [aws_security_group.DivvyCloud-SecurityGroup-Worker.id, var.Bypass-SG]

    root_block_device {
        delete_on_termination = true
        encrypted             = true
        volume_size           = 50
        volume_type           = "gp2"
    }
}

// EC2/UI/Scheduler - Group 1
resource "aws_instance" "DivvyCloud-EC2-UI-Sched" {
    ami                          = var.ami
    associate_public_ip_address  = false
    count                        = 1
    disable_api_termination      = false
    ebs_optimized                = true
    get_password_data            = false
    iam_instance_profile         = var.iam_instance_profile
    instance_type                = "t3.small"
    ipv6_address_count           = 0
    ipv6_addresses               = []
    key_name                     = var.ssh_keypair
    monitoring                   = true
    security_groups              = []
    source_dest_check            = true
    subnet_id                    = var.private_subnet1_id
    tags                         = {
        Name = "DivvyCloud-UI-Sched-${count.index}"
		    Purpose = "Business"
        Product = "DivvyCloud"
        ProductOwner = "cia_security@tavisca.com"
        BusinessUnit = "Security"
        Environment = "Dev"
    }
    tenancy                      = "default"
    user_data_base64             = base64encode(local.ui_sched_user_data)
    volume_tags                  = {
      Name = "DivvyCloud-UI-Sched-${count.index}"
		  Purpose = "Business"
      Product = "DivvyCloud"
      ProductOwner = "cia_security@tavisca.com"
      BusinessUnit = "Security"
      Environment = "Dev"
    }
    vpc_security_group_ids       = [aws_security_group.DivvyCloud-SecurityGroup-UI-Sched.id, aws_security_group.DivvyCloud-SecurityGroup-Worker.id, var.Bypass-SG]

    root_block_device {
        delete_on_termination = true
        encrypted             = true
        volume_size           = 50
        volume_type           = "gp2"
    }
}

// EC2/UI/Scheduler - Group 2
resource "aws_instance" "DivvyCloud-EC2-UI-Sched2" {
    ami                          = var.ami
    associate_public_ip_address  = false
    count                        = 1
    disable_api_termination      = false
    ebs_optimized                = true
    get_password_data            = false
    iam_instance_profile         = var.iam_instance_profile
    instance_type                = "t3.small"
    ipv6_address_count           = 0
    ipv6_addresses               = []
    key_name                     = var.ssh_keypair
    monitoring                   = true
    security_groups              = []
    source_dest_check            = true
    subnet_id                    = var.private_subnet2_id
    tags                         = {
      Name = "DivvyCloud-UI-Sched-${count.index + 1}"
      Purpose = "Business"
      Product = "DivvyCloud"
      ProductOwner = "cia_security@tavisca.com"
      BusinessUnit = "Security"
      Environment = "Dev"
    }
    tenancy                      = "default"
    user_data_base64             = base64encode(local.ui_sched_user_data)
    volume_tags                  = {
      Name = "DivvyCloud-UI-Sched-${count.index + 1}"
      Purpose = "Business"
      Product = "DivvyCloud"
      ProductOwner = "cia_security@tavisca.com"
      BusinessUnit = "Security"
      Environment = "Dev"
    }
    vpc_security_group_ids       = [aws_security_group.DivvyCloud-SecurityGroup-UI-Sched.id, aws_security_group.DivvyCloud-SecurityGroup-Worker.id, var.Bypass-SG]

    root_block_device {
        delete_on_termination = true
        encrypted             = true
        volume_size           = 50
        volume_type           = "gp2"
    }
}

// ALB security group
resource "aws_security_group" "DivvyCloud-SecurityGroup-ALBnew" {
    description = "Web rules for the load balancer"
    name        = "DivvyCloud-SecurityGroup-ALBnew"
    vpc_id      = var.vpc_id
    tags                         = {
      Name = "DivvyCloud-SecurityGroup-ALBnew"
      Purpose = "Business"
      Product = "DivvyCloud"
      ProductOwner = "cia_security@tavisca.com"
      BusinessUnit = "Security"
      Environment = "Dev"
    }
}

// ALB security group ingress rule
resource "aws_security_group_rule" "DivvyCloud-SecurityGroup-ALB" {
    cidr_blocks       = var.ingress_whitelist
    from_port         = 80
    ipv6_cidr_blocks  = []
    prefix_list_ids   = []
    protocol          = "tcp"
    security_group_id = aws_security_group.DivvyCloud-SecurityGroup-ALBnew.id
    self              = false
    to_port           = 80
    type              = "ingress"
}

// ALB security group ingress rule
resource "aws_security_group_rule" "DivvyCloud-SecurityGroup-ALB2" {
    cidr_blocks       = var.ingress_whitelist
    from_port         = 443
    ipv6_cidr_blocks  = []
    prefix_list_ids   = []
    protocol          = "tcp"
    security_group_id = aws_security_group.DivvyCloud-SecurityGroup-ALBnew.id
    self              = false
    to_port           = 443
    type              = "ingress"
}

// ALB security group egress rule
resource "aws_security_group_rule" "DivvyCloud-SecurityGroup-ALB3" {
    cidr_blocks       = var.egress_whitelist
    from_port         = 0
    ipv6_cidr_blocks  = []
    prefix_list_ids   = []
    protocol          = "-1"
    security_group_id = aws_security_group.DivvyCloud-SecurityGroup-ALBnew.id
    self              = false
    to_port           = 0
    type              = "egress"
}

// ALB/Target Group
resource "aws_lb_target_group" "DivvyCloud-ALB-Target-Group" {
  name     = "divvycloud-lb-tg"
  port     = 8001
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  stickiness  {
      enabled = true
      type = "lb_cookie"
      cookie_duration = 3600
  }
  tags                         = {
    Name = "DivvyCloud-ALB-Target-Group"
    Purpose = "Business"
    Product = "DivvyCloud"
    ProductOwner = "cia_security@tavisca.com"
    BusinessUnit = "Security"
    Environment = "Dev"
  }
}

// ALB/Target Group - Members 1
resource "aws_lb_target_group_attachment" "DivvyCloud-ALB-Target-Group-Attachment" {
  target_group_arn = aws_lb_target_group.DivvyCloud-ALB-Target-Group.arn
  target_id        = aws_instance.DivvyCloud-EC2-UI-Sched.0.id
  port             = 8001
         
}

// ALB/Target Group - Members 2
resource "aws_lb_target_group_attachment" "DivvyCloud-ALB-Target-Group-Attachment2" {
  target_group_arn = aws_lb_target_group.DivvyCloud-ALB-Target-Group.arn
  target_id        = aws_instance.DivvyCloud-EC2-UI-Sched2.0.id
  port             = 8001
}

// ALB
resource "aws_lb" "DivvyCloud-ALB" {
  name               = "DivvyCloud-ALB"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.DivvyCloud-SecurityGroup-ALBnew.id]
  subnets            = [var.private_subnet1_id, var.private_subnet2_id]
  idle_timeout       = 600
  enable_deletion_protection = false
  tags = {
    Name = "DivvyCloud-ALB"
    Security = "DivvyCloud"
    Purpose = "Business"
    Product = "DivvyCloud"
    ProductOwner = "cia_security@tavisca.com"
    BusinessUnit = "Security"
    Environment = "Dev"
  }
}

// ALB Secure Listener that forwards to Target Group
resource "aws_lb_listener" "DivvyCloud-ALB-Forward" {
  load_balancer_arn = aws_lb.DivvyCloud-ALB.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = local.ssl_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.DivvyCloud-ALB-Target-Group.arn
  }
}

// ALB Non-Secure Listener that simply redirects to Secure Listener
resource "aws_lb_listener" "DivvyCloud-ALB-Redirect" {
  load_balancer_arn = aws_lb.DivvyCloud-ALB.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}



///Route53

// DNS Canonical Name to forward to the ALB Alias or A-Record
resource "aws_route53_record" "DivvyCloud-CNAME" {
  zone_id = var.Hosted-Zone-ID
  name    = "divvycloud."
  type    = "CNAME"
  ttl     = "60"
  records = [aws_lb.DivvyCloud-ALB.dns_name]
}
