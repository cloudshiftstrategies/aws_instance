# main.tf

# Variables
variable "profile" {
  description = "The AWS CLI profile to use (default: default)"
  default     = "default"
}

variable "region" {
  description = "The region to deploy resources"
  default     = "us-east-1"
}

variable "az" {
  description = "The AZ you want the instance deployed into (0, 1, 2, etc)"
  default     = "a"
}

locals {
  azs = { "a" : 0, "b" : 1, "c" : 2, "d" : 3, "e" : 4, "f" : 5, "g" : 6 }
}

variable "os" {
  description = "The OS to deploy"
  default     = "ubuntu"
}

variable "size" {
  description = "The ec2 instance size"
  default     = "t2.micro"
}

variable "keyfile" {
  description = "The local public key file"
  default     = "~/.ssh/id_rsa.pub"
}

variable "allowed_cidr" {
  description = "The cidr address allowed to access the instance"
  default     = "0.0.0.0/0"
}

# Maps
variable "ami_names" {
  type = "map"

  default = {
    ubuntu = "ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server*"
    aws    = "amzn-ami-hvm-*-x86_64-gp2"
    aws2   = "amzn2-ami-hvm-2.0.*-x86_64-gp2"
  }
}

variable "custom_ami" {
  description = "A custom AMI to use"
  default     = "YOU MUST SPECIFY IF YOU WANT TO USE THIS"
}

variable "os_users" {
  type = "map"

  default = {
    ubuntu = "ubuntu"
    aws    = "ec2-user"
    aws2   = "ec2-user"
  }
}

variable "custom_user" {
  description = "The username to use with your custom AMI"
  default     = "YOU MUST SPECIFY IF YOU WANT TO USE THIS"
}

# Providers
provider "aws" {
  profile = "${var.profile}"
  region  = "${var.region}"
}

# Data lookups
data "aws_ami" "ami" {
  most_recent = true
  # self for own account, conical for ubuntu, or amazon for aws linux
  owners = ["self", "099720109477", "amazon"]

  filter {
    name   = "name"
    values = ["${lookup(var.ami_names, var.os, var.custom_ami)}"]
  }
}

data "aws_vpc" "default" {
  default = "true"
}

# All AZs Available in the current region
data "aws_availability_zones" "available" {}

# Resources
resource "aws_instance" "instance" {
  ami               = "${data.aws_ami.ami.id}"
  instance_type     = "${var.size}"
  availability_zone = "${data.aws_availability_zones.available.names[local.azs[var.az]]}"
  security_groups   = ["${aws_security_group.sec_grp.name}"]
  key_name          = "${aws_key_pair.key.key_name}"
  tags = {
    Name = "temp_tf_instance"
  }
}

resource "aws_key_pair" "key" {
  key_name   = "ssh-key"
  public_key = "${file("${var.keyfile}")}"
}

resource "aws_security_group" "sec_grp" {
  name_prefix = "ssh-only-sg_"
  description = "ssh_only"
  vpc_id      = "${data.aws_vpc.default.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.allowed_cidr}"]
  }
}

# outputs
output "instance_id" {
  value = "${aws_instance.instance.id}"
}
output "ssh_command" {
  value = "ssh -i ${var.keyfile} ${lookup(var.os_users, var.os, var.custom_user)}@${aws_instance.instance.public_ip}"
}
