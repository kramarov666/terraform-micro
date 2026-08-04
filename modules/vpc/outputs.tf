output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_route_table_id" {
  description = "The public route table ID"
  value       = aws_route_table.public.id
}

output "private_route_table_id" {
  description = "The private route table ID"
  value       = aws_route_table.private.id
}
