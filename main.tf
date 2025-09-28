terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1" # O'zgartiring
}

# 1. Default VPC ni olish
data "aws_vpc" "default" {
  default = true
}

# 2. Security Group (SSH va HTTP trafikiga ruxsat)
resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. Ubuntu 22.04 LTS AMI ID (us-east-1)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# 4. EC2 instanslarini yaratish (keysiz)
resource "aws_instance" "web_server" {
  count         = 2
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_http.id]
  # key_name      = "YOUR_KEY_PAIR_NAME" # Key ko'rsatilmaydi

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install -y nginx
              sudo systemctl start nginx
              sudo systemctl enable nginx
              echo "Hello from $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)" > /var/www/html/index.html
              EOF

  tags = {
    Name = "WebServer-${count.index + 1}"
  }
}

# 5. Instanslarning IP manzillarini chiqarib olish
output "instance_ips" {
  value = aws_instance.web_server[*].public_ip
}
