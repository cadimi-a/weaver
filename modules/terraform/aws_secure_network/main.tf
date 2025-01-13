/***********************************************************************************************************************
 $                                                    VPC and Subnet                                                    $
 **********************************************************************************************************************/
resource "aws_vpc" "secure_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = var.name_prefix
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.secure_vpc.id
  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "public" {
  count = length(var.subnet_cidrs.public)

  vpc_id                  = aws_vpc.secure_vpc.id
  cidr_block              = var.subnet_cidrs.public[count.index]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]

  tags = {
    Name = "${var.name_prefix}-public-${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count = length(var.subnet_cidrs.private)

  vpc_id            = aws_vpc.secure_vpc.id
  cidr_block        = var.subnet_cidrs.private[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]

  tags = {
    Name = "${var.name_prefix}-private-${count.index + 1}"
  }
}

resource "aws_subnet" "data" {
  count = length(var.subnet_cidrs.data)

  vpc_id            = aws_vpc.secure_vpc.id
  cidr_block        = var.subnet_cidrs.data[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]

  tags = {
    Name = "${var.name_prefix}-data-${count.index + 1}"
  }
}

resource "aws_flow_log" "vpc" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id               = aws_vpc.secure_vpc.id
  log_destination      = aws_cloudwatch_log_group.vpc_logs[0].arn
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
}

resource "aws_cloudwatch_log_group" "vpc_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "${var.name_prefix}-flow-logs"
  retention_in_days = 90
}

/***********************************************************************************************************************
 $                                                    Security Group                                                    $
 **********************************************************************************************************************/

resource "aws_security_group" "sgs" {
  for_each = toset([for sg in var.security_groups : sg.name])

  name        = each.key
  vpc_id      = aws_vpc.secure_vpc.id
  description = "Managed by Terraform"

  tags = {
    Name = each.key
  }
}

resource "aws_security_group_rule" "ingress" {
  for_each = {
    for idx, inbound in flatten([
      for sg in var.security_groups :
      [
        for rule in sg.inbound :
        {
          security_group_id = aws_security_group.sgs[sg.name].id
          from_port         = rule.from_port
          to_port           = rule.to_port
          protocol          = rule.protocol
          cidr_blocks       = rule.cidr_blocks
          security_groups   = rule.security_groups
        }
      ]
    ]) : idx => inbound
  }

  type                     = "ingress"
  security_group_id        = each.value.security_group_id
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  cidr_blocks              = length(each.value.cidr_blocks) > 0 ? each.value.cidr_blocks : null
  source_security_group_id = length(each.value.security_groups) > 0 ? aws_security_group.sgs[each.value.security_groups[0]].id : null
}


resource "aws_security_group_rule" "egress" {
  for_each = {
    for idx, outbound in flatten([
      for sg in var.security_groups :
      [
        for rule in sg.outbound :
        {
          security_group_id = aws_security_group.sgs[sg.name].id
          from_port         = rule.from_port
          to_port           = rule.to_port
          protocol          = rule.protocol
          cidr_blocks       = rule.cidr_blocks
          security_groups   = rule.security_groups
        }
      ]
    ]) : idx => outbound
  }

  type                     = "egress"
  security_group_id        = each.value.security_group_id
  from_port                = each.value.from_port
  to_port                  = each.value.to_port
  protocol                 = each.value.protocol
  cidr_blocks              = length(each.value.cidr_blocks) > 0 ? each.value.cidr_blocks : null
  source_security_group_id = length(each.value.security_groups) > 0 ? aws_security_group.sgs[each.value.security_groups[0]].id : null
}

/***********************************************************************************************************************
 $                                                    VPC Endpoints                                                    $
 **********************************************************************************************************************/

resource "aws_vpc_endpoint" "endpoints" {
  for_each = { for idx, endpoint in var.vpc_endpoints : idx => endpoint }

  vpc_id            = aws_vpc.secure_vpc.id
  service_name      = each.value.service_name
  vpc_endpoint_type = each.value.type

  route_table_ids = each.value.type == "Gateway" ? [
    aws_route_table.private.id
  ] : null

  subnet_ids = each.value.type == "Interface" ? [
    aws_subnet.private[0].id
  ] : null

  security_group_ids = each.value.type == "Interface" ? [
    aws_security_group.sgs["allowing-internal-sg"].id
  ] : null

  private_dns_enabled = each.value.type == "Interface" ? true : false

  tags = {
    Name = "${var.name_prefix}-vpc-endpoint-${each.key}"
  }
}

/***********************************************************************************************************************
 $                                                         NAT                                                         $
 **********************************************************************************************************************/

resource "aws_nat_gateway" "nat" {
  count = var.enable_nat_gateways ? 1 : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "${var.name_prefix}-nat-gateway-${count.index + 1}"
  }
}

resource "aws_eip" "nat" {
  count = var.enable_nat_gateways ? 1 : 0

  tags = {
    Name = "${var.name_prefix}-eip-${count.index + 1}"
  }
}

resource "aws_instance" "nat_instance" {
  count = var.enable_nat_gateways ? 0 : 1

  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.nat_instance_type
  subnet_id     = aws_subnet.public[0].id

  source_dest_check = false
  associate_public_ip_address = true
  security_groups = [
    aws_security_group.sgs["allowing-internal-sg"].id
  ]

  tags = {
    Name = "${var.name_prefix}-nat-instance-${count.index + 1}"
  }

  iam_instance_profile = aws_iam_instance_profile.ssm_instance_profile[0].name

  user_data = <<-EOF
      #!/bin/bash
      # Enable IP forwarding
      echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
      sysctl -p

      # Install iptables services
      yum install -y iptables-services
      systemctl enable iptables
      systemctl start iptables

      # Configure NAT
      /sbin/iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

      # Allow forwarding traffic
      /sbin/iptables -A FORWARD -i eth0 -j ACCEPT
      /sbin/iptables -A FORWARD -o eth0 -j ACCEPT

      # Remove any default REJECT rules in FORWARD chain
      /sbin/iptables -D FORWARD -j REJECT --reject-with icmp-host-prohibited || true

      # Save iptables rules
      iptables-save > /etc/sysconfig/iptables
  EOF

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}

resource "aws_iam_role" "ssm_role" {
  count = var.enable_nat_gateways ? 0 : 1

  name = "${var.name_prefix}-nat-instance-ssm"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  count = var.enable_nat_gateways ? 0 : 1

  role       = aws_iam_role.ssm_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_instance_profile" {
  count = var.enable_nat_gateways ? 0 : 1

  name = "${var.name_prefix}-nat-instance-ssm"
  role = aws_iam_role.ssm_role[0].name
}

/***********************************************************************************************************************
 $                                                     Route Table                                                     $
 **********************************************************************************************************************/

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.secure_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.name_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  for_each = {for index, subnet in aws_subnet.public : index => subnet}

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.secure_vpc.id

  route {
    cidr_block              = "0.0.0.0/0"
    nat_gateway_id          = var.enable_nat_gateways ? aws_nat_gateway.nat[0].id : null
    network_interface_id    = !var.enable_nat_gateways ? aws_instance.nat_instance[0].primary_network_interface_id : null
  }

  tags = {
    Name = "${var.name_prefix}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  for_each = {for index, subnet in aws_subnet.private : index => subnet}

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table" "data" {
  vpc_id = aws_vpc.secure_vpc.id

  tags = {
    Name = "${var.name_prefix}-data-rt"
  }
}

resource "aws_route_table_association" "data" {
  for_each = {for index, subnet in aws_subnet.data : index => subnet}

  subnet_id      = each.value.id
  route_table_id = aws_route_table.data.id
}
