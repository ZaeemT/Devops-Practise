terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}


# Create a VPC
resource "aws_vpc" "test_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "test_vpc"
  }
}

resource "aws_subnet" "test_public" {
  vpc_id     = aws_vpc.test_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "test_private" {
  vpc_id     = aws_vpc.test_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = false
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.test_vpc.id
}

resource "aws_route_table" "test_public_route_table" {
  vpc_id = aws_vpc.test_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table" "test_private_route_table" {
  vpc_id = aws_vpc.test_vpc.id

#  route {
#    cidr_block = "0.0.0.0/0"
#    gateway_id = aws_internet_gateway.igw.id
#  }
}


resource "aws_route_table_association" "private_subnet_association" {
  subnet_id      = aws_subnet.test_private.id
  route_table_id = aws_route_table.test_private_route_table.id
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.test_public.id
  route_table_id = aws_route_table.test_public_route_table.id
} 


# Create security group
resource "aws_security_group" "react_web_sg" {
  name        = "react_web_sg"
  description = "sg for web"
  vpc_id      = aws_vpc.test_vpc.id

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

}


# Generate ke pair
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("~/.ssh/my-key.pub")
}

# Ubuntu 20.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# Make and launch ec2 instance
resource "aws_instance" "react_web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.test_public.id
  key_name      = aws_key_pair.deployer.id
  vpc_security_group_ids = [aws_security_group.react_web_sg.id]

  user_data = file("./user_data.sh")

  tags = {
    Name = "test-web"
  }


}