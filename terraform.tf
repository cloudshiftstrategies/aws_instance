# main.tf

# Variables
variable "region" {
  description = "The region to deploy resources"
  default     = "us-east-1"
}

variable "os" {
  description = "The OS to deploy"
  default     = "ubuntu"
}

variable "size" {
	description = "The ec2 instance size"
	default = "t2.micro"
}

variable "keyfile" {
	description = "The local public key file"
	default = "~/.ssh/id_rsa.pub"
}

variable "allowed_cidr" {
	description = "The cidr address allowed to access the instance"
	default = "0.0.0.0/0"
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

variable "os_users" {
  type = "map"

  default = {
    ubuntu = "ubuntu"
    aws    = "ec2-user"
    aws2   = "ec2-user"
  }
}

# Providers
provider "aws" {
  region = "${var.region}"
}

# Data lookups
data "aws_ami" "ami" {
  most_recent = true

  filter {
    name   = "name"
    values = ["${var.ami_names["${var.os}"]}"]
  }
}

data "aws_vpc" "default" {
	default = "true"
}

# Resources
resource "aws_instance" "instance" {
  ami             = "${data.aws_ami.ami.id}"
  instance_type   = "${var.size}"
  security_groups = ["${aws_security_group.sec_grp.name}"]
  key_name        = "${aws_key_pair.key.key_name}"
	tags {
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
  value = "ssh -i ${var.keyfile} ${var.os_users["${var.os}"]}@${aws_instance.instance.public_ip}"
}
