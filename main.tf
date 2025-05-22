locals {
  volume_name = var.name
  # Parse comma-separated subnet IDs into a list
  provided_subnet_ids = var.subnet_ids != "" ? split(",", var.subnet_ids) : []
  # Parse comma-separated security group IDs into a list
  provided_security_group_ids = var.security_group_ids != "" ? split(",", var.security_group_ids) : []
  # Determine if we should use provided VPC/subnets or default
  use_provided_network = var.vpc_id != "" && length(local.provided_subnet_ids) > 0
}

# Generate random suffix for unique resource naming
resource "random_id" "suffix" {
  byte_length = 4
}

# Get default VPC and subnets (used when no custom VPC provided)
data "aws_vpc" "default" {
  count   = local.use_provided_network ? 0 : 1
  default = true
}

data "aws_subnets" "default" {
  count = local.use_provided_network ? 0 : 1
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default[0].id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Get provided VPC information (used when custom VPC provided)
data "aws_vpc" "provided" {
  count = local.use_provided_network ? 1 : 0
  id    = var.vpc_id
}

# Determine which VPC and subnets to use
locals {
  target_vpc_id    = local.use_provided_network ? data.aws_vpc.provided[0].id : data.aws_vpc.default[0].id
  target_vpc_cidr  = local.use_provided_network ? data.aws_vpc.provided[0].cidr_block : data.aws_vpc.default[0].cidr_block
  target_subnet_ids = local.use_provided_network ? local.provided_subnet_ids : data.aws_subnets.default[0].ids
}

# Create security group for EFS (only if no security groups provided)
resource "aws_security_group" "efs" {
  count       = length(local.provided_security_group_ids) > 0 ? 0 : 1
  name        = "${local.volume_name}-efs-sg-${random_id.suffix.hex}"
  description = "Allow NFS traffic to EFS"
  vpc_id      = local.target_vpc_id

  ingress {
    description = "NFS from VPC"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [local.target_vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.volume_name}-efs-sg"
  }
}

# Determine which security groups to use
locals {
  target_security_groups = length(local.provided_security_group_ids) > 0 ? local.provided_security_group_ids : [aws_security_group.efs[0].id]
}

# Create EFS file system
resource "aws_efs_file_system" "this" {
  creation_token = "${local.volume_name}-efs-${random_id.suffix.hex}"
  encrypted      = true

  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  tags = {
    Name = local.volume_name
  }
}

# Create mount targets in all available subnets
resource "aws_efs_mount_target" "this" {
  count           = length(local.target_subnet_ids)
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = local.target_subnet_ids[count.index]
  security_groups = local.target_security_groups
}

# Wait for EFS mount targets to become fully available
resource "time_sleep" "wait_for_efs_mount_targets" {
  depends_on      = [aws_efs_mount_target.this]
  create_duration = "90s"
}

# Create access point with proper directory permissions
resource "aws_efs_access_point" "this" {
  file_system_id = aws_efs_file_system.this.id
  depends_on     = [time_sleep.wait_for_efs_mount_targets]

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/${local.volume_name}"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  tags = {
    Name = "${local.volume_name}-access-point"
  }
}