terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.54.0"
    }
  }
}

variable "aws_key" {
  sensitive = true
}

variable "aws_secret" {
  sensitive = true
}

provider "aws" {
  # Configuration options
  region = "us-east-1"
  access_key = var.aws_key
  secret_key = var.aws_secret
}

# resource "aws_instance" "first-server" {  

#   ami = "ami-0557a15b87f6559cf"
#   instance_type = "t2.micro"

#   tags = {
#     Name = "JosephTestingTerraform"
#   }

# }

resource "aws_vpc" "joseph-vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "Joseph-vpc"
  }
}

resource "aws_internet_gateway" "joseph-gw" {
  vpc_id = aws_vpc.joseph-vpc.id

  tags = {
    Name = "joseph-gw"
  }
}

resource "aws_route_table" "joseph-route-table" {
  vpc_id = aws_vpc.joseph-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.joseph-gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.joseph-gw.id
  }

  tags = {
    Name = "joseph-route-table"
  }
}

resource "aws_subnet" "joseph-subnet" {
  vpc_id     = aws_vpc.joseph-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "joseph-subnet"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.joseph-subnet.id
  route_table_id = aws_route_table.joseph-route-table.id
}

resource "aws_security_group" "allow_web_traffic" {
  name        = "allow_web_traffic"
  description = "Allow web inbound traffic"
  vpc_id      = aws_vpc.joseph-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

resource "aws_network_interface" "web-server-joseph" {
  subnet_id       = aws_subnet.joseph-subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web_traffic.id]

}

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-joseph.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [
    aws_internet_gateway.joseph-gw
  ]
}

resource "aws_instance" "joseph-web-server" {
  ami           = "ami-0557a15b87f6559cf"
  instance_type = "t3.micro"
  availability_zone = aws_subnet.joseph-subnet.availability_zone
  key_name = "joseph-key-pair"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-joseph.id
  }

  tags = {
    Name = "JosephWebServer"
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo Hello World > /var/www/html/index.html'
            EOF
}

output "server_public_id" {
  value = aws_eip.one.public_ip
}


