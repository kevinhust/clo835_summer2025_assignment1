provider "aws" {
  region = var.aws_region
}

# Create ECR repository for webapp
resource "aws_ecr_repository" "webapp" {
  name                 = var.webapp_ecr_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = var.webapp_ecr_name
    Environment = var.environment
    Project     = var.project
  }
}

# Create ECR repository for mysql
resource "aws_ecr_repository" "mysql" {
  name                 = var.mysql_ecr_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = var.mysql_ecr_name
    Environment = var.environment
    Project     = var.project
  }
}

# Create IAM role for EC2
resource "aws_iam_role" "ec2_ecr_role" {
  name = "ec2_ecr_access_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach ECR access policy
resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.ec2_ecr_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECR-FullAccess"
}

# Create instance profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_ecr_profile"
  role = aws_iam_role.ec2_ecr_role.name
}

# Create security group
resource "aws_security_group" "ec2_sg" {
  name        = var.ec2_sg_name
  description = var.ec2_sg_description

  # Allow SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow application ports
  ingress {
    from_port   = 8081
    to_port     = 8083
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = var.ec2_sg_name
    Environment = var.environment
    Project     = var.project
  }
}

# Create EC2 key pair for SSH access
resource "aws_key_pair" "CLO835A1" {
  key_name   = var.key_pair_name
  public_key = file("${path.module}/${var.key_pair_name}.pub")
}

# Create EC2 instance
resource "aws_instance" "docker_host" {
  ami                    = var.ec2_ami
  instance_type          = var.ec2_instance_type
  key_name               = aws_key_pair.CLO835A1.key_name
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y docker
              systemctl start docker
              systemctl enable docker
              usermod -a -G docker ec2-user
              EOF

  tags = {
    Name        = var.ec2_tag_name
    Environment = var.environment
    Project     = var.project
  }
}

# Outputs
output "ecr_webapp_repository_url" {
  value = aws_ecr_repository.webapp.repository_url
}

output "ecr_mysql_repository_url" {
  value = aws_ecr_repository.mysql.repository_url
}

output "ec2_public_ip" {
  value = aws_instance.docker_host.public_ip
}