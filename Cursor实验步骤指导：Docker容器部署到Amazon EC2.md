# Cursor实验步骤指导：Docker容器部署到Amazon EC2

本指导文档提供了使用Cursor完成Assignment1的详细步骤，包括创建Dockerfile、构建Docker镜像、配置GitHub Actions以及在Amazon EC2上部署容器。

## 目录

1. [准备工作](#准备工作)
2. [Terraform部署基础设施](#terraform部署基础设施)
3. [配置GitHub仓库](#配置github仓库)
4. [创建Dockerfile和构建镜像](#创建dockerfile和构建镜像)
5. [配置GitHub Actions工作流](#配置github-actions工作流)
6. [EC2实例操作](#ec2实例操作)
7. [容器部署与验证](#容器部署与验证)
8. [实验报告编写](#实验报告编写)

## 准备工作

### 1. 环境准备

```bash
# 在Cursor中打开终端，确认AWS CLI已安装
aws --version

# 如未安装，执行安装命令
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# 配置AWS凭证
aws configure
# 按提示输入Access Key、Secret Key、默认区域(us-east-1)和输出格式(json)

# 安装Terraform
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common
wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt-get update && sudo apt-get install terraform

# 安装Docker
sudo apt-get install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
# 注意：添加用户到docker组后需要重新登录才能生效
```

### 2. 克隆示例应用仓库

```bash
# 克隆示例应用仓库
git clone https://github.com/codesavvysm/clo835_summer2025_assignment1.git
cd clo835_summer2025_assignment1
```

## Terraform部署基础设施

### 1. 创建Terraform配置文件

在项目根目录创建`terraform`文件夹，并在其中创建以下文件：

**main.tf**:

```hcl
provider "aws" {
  region = "us-east-1"
}

# 创建ECR仓库 - webapp
resource "aws_ecr_repository" "webapp" {
  name                 = "webapp-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# 创建ECR仓库 - mysql
resource "aws_ecr_repository" "mysql" {
  name                 = "mysql-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# 创建IAM角色供EC2使用
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

# 附加ECR访问策略
resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.ec2_ecr_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECR-FullAccess"
}

# 创建实例配置文件
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_ecr_profile"
  role = aws_iam_role.ec2_ecr_role.name
}

# 创建安全组
resource "aws_security_group" "ec2_sg" {
  name        = "ec2_docker_sg"
  description = "Allow SSH and web traffic"

  # SSH访问
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 应用端口访问
  ingress {
    from_port   = 8081
    to_port     = 8083
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 出站规则
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 创建EC2实例
resource "aws_instance" "docker_host" {
  ami                    = "ami-0c7217cdde317cfec" # Amazon Linux 2023 AMI ID，可能需要更新
  instance_type          = "t2.micro"
  key_name               = "your-key-pair" # 替换为您的密钥对名称
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
    Name = "DockerHost"
  }
}

# 输出
output "ecr_webapp_repository_url" {
  value = aws_ecr_repository.webapp.repository_url
}

output "ecr_mysql_repository_url" {
  value = aws_ecr_repository.mysql.repository_url
}

output "ec2_public_ip" {
  value = aws_instance.docker_host.public_ip
}
```

**variables.tf**:

```hcl
variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "key_name" {
  description = "Name of the SSH key pair"
  default     = "your-key-pair" # 替换为您的密钥对名称
}
```

### 2. 初始化并应用Terraform配置

```bash
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
```

### 3. 记录输出信息

```bash
# 记录ECR仓库URL和EC2公共IP地址
terraform output
```

## 配置GitHub仓库

### 1. 创建新的GitHub仓库

1. 登录GitHub账户
2. 创建新仓库，命名为`clo835-assignment1`
3. 设置为私有仓库
4. 初始化仓库并添加README.md

### 2. 保护主分支

1. 进入仓库设置 -> Branches
2. 添加分支保护规则
3. 选择`main`分支
4. 勾选"Require pull request reviews before merging"
5. 勾选"Require status checks to pass before merging"
6. 保存更改

### 3. 配置GitHub Secrets

1. 进入仓库设置 -> Secrets and variables -> Actions
2. 添加以下secrets:
   - `AWS_ACCESS_KEY_ID`: AWS访问密钥ID
   - `AWS_SECRET_ACCESS_KEY`: AWS秘密访问密钥
   - `AWS_REGION`: AWS区域(us-east-1)
   - `ECR_REPOSITORY_WEBAPP`: Webapp ECR仓库URL(不含协议和标签)
   - `ECR_REPOSITORY_MYSQL`: MySQL ECR仓库URL(不含协议和标签)

### 4. 克隆仓库到本地

```bash
git clone https://github.com/你的用户名/clo835-assignment1.git
cd clo835-assignment1
```

### 5. 创建开发分支

```bash
git checkout -b development
```

## 创建Dockerfile和构建镜像

### 1. 复制示例应用代码

```bash
# 复制示例应用代码到新仓库
cp -r ../clo835_summer2025_assignment1/* .
```

### 2. 创建MySQL Dockerfile

在项目根目录创建`mysql/Dockerfile`:

```dockerfile
FROM mysql:5.7

ENV MYSQL_DATABASE=employees
ENV MYSQL_USER=admin
ENV MYSQL_PASSWORD=admin123
ENV MYSQL_ROOT_PASSWORD=admin123

COPY ./mysql/init.sql /docker-entrypoint-initdb.d/

EXPOSE 3306
```

### 3. 创建MySQL初始化脚本

在`mysql`目录下创建`init.sql`:

```sql
CREATE DATABASE IF NOT EXISTS employees;
USE employees;

CREATE TABLE IF NOT EXISTS employee (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  position VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO employee (name, position) VALUES ('John Doe', 'Developer');
INSERT INTO employee (name, position) VALUES ('Jane Smith', 'Designer');
INSERT INTO employee (name, position) VALUES ('Bob Johnson', 'Manager');
```

### 4. 创建Web应用Dockerfile

在项目根目录创建`webapp/Dockerfile`:

```dockerfile
FROM python:3.9-slim

WORKDIR /app

COPY ./webapp/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY ./webapp/ .

ENV APP_COLOR=blue
ENV MYSQL_HOST=mysql
ENV MYSQL_USER=admin
ENV MYSQL_PASSWORD=admin123
ENV MYSQL_DATABASE=employees

EXPOSE 8080

CMD ["python", "app.py"]
```

### 5. 本地测试构建镜像

```bash
# 构建MySQL镜像
docker build -t mysql:v1 -f mysql/Dockerfile .

# 构建Web应用镜像
docker build -t webapp:v1 -f webapp/Dockerfile .

# 创建自定义网络
docker network create app-network

# 运行MySQL容器
docker run -d --name mysql --network app-network mysql:v1

# 运行Web应用容器(蓝色背景)
docker run -d --name blue --network app-network -p 8081:8080 -e APP_COLOR=blue webapp:v1

# 测试连接
curl http://localhost:8081
```

## 配置GitHub Actions工作流

### 1. 创建GitHub Actions工作流文件

在项目根目录创建`.github/workflows/docker-build.yml`:

```yaml
name: Build and Push Docker Images

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v1
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ${{ secrets.AWS_REGION }}
    
    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v1
    
    - name: Build and push MySQL image
      uses: docker/build-push-action@v2
      with:
        context: .
        file: ./mysql/Dockerfile
        push: true
        tags: ${{ secrets.ECR_REPOSITORY_MYSQL }}:latest
    
    - name: Build and push WebApp image
      uses: docker/build-push-action@v2
      with:
        context: .
        file: ./webapp/Dockerfile
        push: true
        tags: ${{ secrets.ECR_REPOSITORY_WEBAPP }}:latest
```

### 2. 提交代码并推送到开发分支

```bash
git add .
git commit -m "Initial commit with application code and GitHub Actions workflow"
git push origin development
```

### 3. 创建Pull Request并合并到主分支

1. 在GitHub仓库页面创建Pull Request
2. 从`development`分支到`main`分支
3. 添加标题和描述
4. 创建Pull Request
5. 等待GitHub Actions工作流完成
6. 合并Pull Request

## EC2实例操作

### 1. 连接到EC2实例

```bash
# 使用SSH连接到EC2实例
ssh -i "your-key-pair.pem" ec2-user@<EC2_PUBLIC_IP>
```

### 2. 配置Docker和AWS

```bash
# 确认Docker已安装并运行
sudo systemctl status docker

# 配置AWS CLI(如果需要)
aws configure
```

### 3. 登录到ECR并拉取镜像

```bash
# 获取ECR登录令牌
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <AWS_ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

# 拉取MySQL镜像
docker pull <ECR_REPOSITORY_MYSQL>:latest

# 拉取WebApp镜像
docker pull <ECR_REPOSITORY_WEBAPP>:latest
```

## 容器部署与验证

### 1. 创建自定义网络

```bash
docker network create app-network
```

### 2. 运行MySQL容器

```bash
docker run -d --name mysql --network app-network <ECR_REPOSITORY_MYSQL>:latest
```

### 3. 测试MySQL连接

```bash
# 使用MySQL客户端测试连接
docker run -it --rm --network app-network mysql:5.7 mysql -hmysql -uadmin -padmin123 -e "SHOW DATABASES;"
```

### 4. 运行Web应用容器(不同颜色)

```bash
# 蓝色背景 - 端口8081
docker run -d --name blue --network app-network -p 8081:8080 -e APP_COLOR=blue <ECR_REPOSITORY_WEBAPP>:latest

# 粉色背景 - 端口8082
docker run -d --name pink --network app-network -p 8082:8080 -e APP_COLOR=pink <ECR_REPOSITORY_WEBAPP>:latest

# 绿色背景 - 端口8083
docker run -d --name lime --network app-network -p 8083:8080 -e APP_COLOR=lime <ECR_REPOSITORY_WEBAPP>:latest
```

### 5. 验证应用可访问性

```bash
# 测试蓝色应用
curl http://localhost:8081

# 测试粉色应用
curl http://localhost:8082

# 测试绿色应用
curl http://localhost:8083

# 从外部测试(使用EC2公共IP)
curl http://<EC2_PUBLIC_IP>:8081
curl http://<EC2_PUBLIC_IP>:8082
curl http://<EC2_PUBLIC_IP>:8083
```

### 6. 测试容器间通信

```bash
# 进入蓝色容器
docker exec -it blue /bin/bash

# 从蓝色容器ping其他容器
ping pink
ping lime
ping mysql

# 退出容器
exit
```

## 实验报告编写

### 1. 报告内容要点

1. 实验过程描述
2. 遇到的挑战和解决方案
3. 回答问题：为什么可以在单个EC2实例上运行3个监听相同端口(8080)的应用？
   - 答案：因为容器使用了端口映射，将主机的不同端口(8081/8082/8083)映射到容器内的相同端口(8080)。每个容器都有自己的网络命名空间，因此可以在容器内使用相同的端口而不会冲突。

### 2. 录制演示视频

按照评分标准录制演示视频，确保涵盖以下内容：
1. Terraform部署ECR和EC2
2. GitHub Actions自动构建和推送镜像
3. EC2上拉取和运行容器
4. 应用访问测试
5. 容器间通信测试

## 提交要求

1. GitHub仓库链接(包含应用代码和GitHub Actions工作流)
2. Terraform代码仓库链接
3. 演示视频
4. 实验报告

## 注意事项

1. 确保所有提交日期在截止日期之前
2. 不要提交Terraform状态文件
3. 实验报告必须包含您在实验过程中遇到的挑战和解决方案
4. 避免抄袭，确保所有工作都是您自己完成的
