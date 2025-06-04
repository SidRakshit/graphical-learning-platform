// terraform/environments/dev/outputs.tf

output "vpc_id" {
  description = "The ID of the main VPC created."
  value       = aws_vpc.main.id // References the 'id' attribute of the 'aws_vpc' resource named 'main' in main.tf
}

output "public_subnet_ids" {
  description = "A list of IDs of the public subnets created."
  value       = [
    aws_subnet.public_az1.id,
    aws_subnet.public_az2.id
  ] // Creates a list of the IDs of your public subnets
}

output "private_subnet_ids" {
  description = "A list of IDs of the private subnets created."
  value       = [
    aws_subnet.private_az1.id,
    aws_subnet.private_az2.id
  ] // Creates a list of the IDs of your private subnets
}

output "nat_gateway_public_ip" {
  description = "The public IP address of the NAT Gateway in AZ1."
  value       = aws_eip.nat_gateway_az1_eip.public_ip // References the 'public_ip' attribute of the Elastic IP
}

output "availability_zones_used" {
  description = "The Availability Zones used for the subnets."
  value       = var.availability_zones // Outputs the value of the input variable
}

output "ssh_security_group_id" {
  description = "The ID of the Security Group that allows SSH access."
  value       = aws_security_group.allow_ssh.id
}

output "web_security_group_id" {
  description = "The ID of the Security Group that allows Web (HTTP/HTTPS) access."
  value       = aws_security_group.allow_web.id
}