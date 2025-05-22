output "efs_arn" {
  description = "ARN of the EFS file system"
  value       = aws_efs_file_system.this.arn
}

output "efs_id" {
  description = "ID of the EFS file system"
  value       = aws_efs_file_system.this.id
}

output "mount_targets" {
  description = "List of EFS mount target IDs in default subnets"
  value       = aws_efs_mount_target.this[*].id
}

output "access_point_arn" {
  description = "ARN of the EFS access point"
  value       = aws_efs_access_point.this.arn
}