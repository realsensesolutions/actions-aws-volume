locals {
  volume_name = var.name
}

# Generate random suffix for unique resource naming
resource "random_id" "suffix" {
  byte_length = 4
}

# Get default VPC and subnets
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Create security group for EFS
resource "aws_security_group" "efs" {
  name        = "${local.volume_name}-efs-sg-${random_id.suffix.hex}"
  description = "Allow NFS traffic to EFS"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "NFS from VPC"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.default.cidr_block]
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
  count           = length(data.aws_subnets.default.ids)
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = data.aws_subnets.default.ids[count.index]
  security_groups = [aws_security_group.efs.id]
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