output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.secure_vpc.id
}

output "public_subnet_ids" {
  description = "The IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "The IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "data_subnet_ids" {
  description = "The IDs of the data subnets"
  value       = aws_subnet.data[*].id
}

output "security_groups" {
  description = "The security groups"
  value       = aws_security_group.sgs
}

output "igw_id" {
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.igw.id
}

output "nat_gateway_id" {
  description = "The IDs of the NAT Gateway"
  value       = aws_nat_gateway.nat[*].id
}

output "nat_instance_id" {
  description = "The ID of the NAT Instance"
  value       = aws_instance.nat_instance[*].id
}