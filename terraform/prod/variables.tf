variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "webapp_ecr_name" {
  description = "ECR repository name for webapp"
  default     = "webapp-repo"
}

variable "mysql_ecr_name" {
  description = "ECR repository name for mysql"
  default     = "mysql-repo"
}

variable "ec2_ami" {
  description = "AMI ID for EC2 instance"
  default     = "ami-0c7217cdde317cfec"
}

variable "ec2_instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro"
}

variable "ec2_sg_name" {
  description = "EC2 security group name"
  default     = "ec2_docker_sg"
}

variable "ec2_sg_description" {
  description = "EC2 security group description"
  default     = "Allow SSH and web traffic"
}

variable "ec2_tag_name" {
  description = "EC2 tag Name"
  default     = "DockerHost"
}

variable "key_pair_name" {
  description = "EC2 key pair name"
  default     = "CLO835A1"
}

variable "environment" {
  description = "Deployment environment (prod or staging)"
  default     = "prod"
}

variable "project" {
  description = "Project name for tagging"
  default     = "clo835"
}