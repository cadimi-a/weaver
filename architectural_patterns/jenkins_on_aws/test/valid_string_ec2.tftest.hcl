# valid_string_ec2.tftest.hcl

mock_provider "aws" {}

variables {
  region       = "us-east-1"
  name_tag     = "jenkins_on_aws"
  developer_ip = "111.11.111.111"
}

# Security Group
run "valid_ec2_security_group_name" {
  command = plan

  assert {
    condition     = aws_security_group.web_server_sg.tags.Name == "jenkins_on_aws"
    error_message = "SG bucket name did not match expected"
  }
}

run "valid_ec2_security_group_rule_ssh" {
  command = plan

  assert {
    condition     = aws_vpc_security_group_ingress_rule.web_server_sg_rule_ssh.cidr_ipv4 == "111.11.111.111/32"
    error_message = "developer ip did not match expected in sg rule ssh"
  }
}

run "valid_ec2_security_group_rule_http" {
  command = plan

  assert {
    condition     = aws_vpc_security_group_ingress_rule.web_server_sg_rule_http.cidr_ipv4 == "111.11.111.111/32"
    error_message = "developer ip did not match expected in sg rule http"
  }
}

run "valid_ec2_security_group_rule_custom_tcp_rule" {
  command = plan

  assert {
    condition     = aws_vpc_security_group_ingress_rule.web_server_sg_rule_custom_tcp_rule.cidr_ipv4 == "111.11.111.111/32"
    error_message = "developer ip did not match expected in sg rule custom tcp rule"
  }
}

# EC2 Instance
run "valid_ec2_instance_name" {
  command = plan

  assert {
    condition     = aws_instance.web_server.tags.Name == "jenkins_on_aws"
    error_message = "instance name did not match expected"
  }
}