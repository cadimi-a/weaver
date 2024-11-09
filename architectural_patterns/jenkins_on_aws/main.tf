locals {
  tags = {
    Name = var.name_tag
  }

  vpc_cidr_block    = "10.0.0.0/16"
  subnet_cidr_block = "10.0.0.0/24"
  ec2_instance_type = "t2.micro"
}

# Creating a key pair
# https://www.jenkins.io/doc/tutorials/tutorial-for-installing-jenkins-on-AWS/#creating-a-key-pair
resource "aws_key_pair" "deployer" {
  key_name = "deployer-key"
  public_key = file("~/.ssh/deployer-key.pub")
}

# Creating a security group
# https://www.jenkins.io/doc/tutorials/tutorial-for-installing-jenkins-on-AWS/#creating-a-security-group
resource "aws_security_group" "web_server_sg" {
  name        = "WebServerSG"
  description = "WebServerSG created"
  vpc_id      = aws_vpc.vpc.id

  tags = local.tags
}

resource "aws_vpc_security_group_ingress_rule" "web_server_sg_rule_ssh" {
  security_group_id = aws_security_group.web_server_sg.id
  cidr_ipv4         = "${var.developer_ip}/32"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22

  tags = local.tags

}

resource "aws_vpc_security_group_ingress_rule" "web_server_sg_rule_http" {
  security_group_id = aws_security_group.web_server_sg.id
  cidr_ipv4         = "${var.developer_ip}/32"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80

  tags = local.tags
}

resource "aws_vpc_security_group_ingress_rule" "web_server_sg_rule_custom_tcp_rule" {
  security_group_id = aws_security_group.web_server_sg.id
  cidr_ipv4         = "${var.developer_ip}/32"
  ip_protocol       = "tcp"
  from_port         = 8080
  to_port           = 8080

  tags = local.tags
}

resource "aws_vpc_security_group_egress_rule" "web_server_sg_rule_all" {
  security_group_id = aws_security_group.web_server_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Launching an Amazon EC2 instance
# https://www.jenkins.io/doc/tutorials/tutorial-for-installing-jenkins-on-AWS/#launching-an-amazon-ec2-instance
data "aws_ami" "amzn-linux-2023-ami" {
  most_recent = true
  owners = ["amazon"]

  filter {
    name = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

resource "aws_instance" "web_server" {
  depends_on = [
    aws_key_pair.deployer,
    aws_security_group.web_server_sg
  ]

  ami                         = data.aws_ami.amzn-linux-2023-ami.id
  instance_type               = local.ec2_instance_type
  key_name                    = aws_key_pair.deployer.key_name
  subnet_id                   = aws_subnet.subnet.id
  associate_public_ip_address = true
  security_groups = [
    aws_security_group.web_server_sg.id
  ]

  # Downloading and installing Jenkins
  # https://www.jenkins.io/doc/tutorials/tutorial-for-installing-jenkins-on-AWS/#downloading-and-installing-jenkins
  user_data = file("/app/scripts/installing_jenkins.sh")

  tags = local.tags
}

resource "aws_vpc" "vpc" {
  cidr_block = local.vpc_cidr_block
  enable_dns_hostnames = true

  tags = local.tags
}

# Network configuration
resource "aws_subnet" "subnet" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = local.subnet_cidr_block

  tags = local.tags
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = local.tags
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  route {
    cidr_block = local.vpc_cidr_block
    gateway_id = "local"
  }
}

resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.rt.id
}