# aws_instance project

Very simple tools for launching a quick EC2 instance without having to go to AWS console

It seems like I am often working on the CLI and need a quick EC2 instance fired up to test something.
I can never remember the exact command sequence to make using the CLI after than going to the console,
and setting up terraform for a single instance always seems like too much work. So I have to break my
flow, log into AWS console, create the instance, copy the public IP and get back to work. 

This tool is designed to allow my to crank out an ec2 linux instance in a flash, without leaving the cli. 

This repo includes two versions of the tool.
cli_instance.sh performs the operations using awscli and bash
tf_instance.sh performs operations using terraform aws provider. ** This version is always going to be more robust


## Subcommands:
* launch:
	*	Creates an ssh-key names after the local host name (if required)
	*	Launches a linux t2.micro instance of type ubuntu, aws or aws2
	*	Stores the instance ids launched in the instances.log file for cli_instance.sh or in terraform state for tf_instance.sh
	* Provide connection instructions

* list:
	* list the deployed instances

* terminate:
	*	Terminates all of the ec2 instances in instances.log (or terraform state)
	* deletes instances.log

## Requirements

* Linux or mac workstation with bash & openssh installed
* awscli. Required only for cli_instance.sh version. install with `pip install awscli`)
* terraform. Required only for the tf_instances.sh version. [install instructions](https://learn.hashicorp.com/terraform/getting-started/install.html)

## Usage

		# Terraform version
		USAGE: ./tf_instance.sh launch|list|terminate [ubuntu|aws|aws2]

or

		# AWS CLI version
		USAGE: ./cli_instance.sh launch|list|terminate [ubuntu|aws|aws2]

## Example usage

the following commands work the same for cli_instance.sh and tf_instance.sh

Launch an aws linux 2 instance in the current region (defined by AWS_DEFAULT_REGION env var)

		$ ./cli_instance.sh launch aws2
		Launching (1) aws2 instance size: t2.micro in us-east-1
		Looking up latest AMI for aws2... found: ami-009d6802948d06e52
		Using existing AWS key name: peterb154-asus-laptop
		Launching instance id: i-0c25a87f27b967980
		Connect with: ssh -i /home/peterb154/.ssh/id_rsa.pub ec2-user@54.81.198.132

List all launched instances and thier public IPs

		$ ./cli_instance.sh list
		i-0c25a87f27b967980 54.81.198.132

Terminate all launched instances

		$ ./cli_instance.sh terminate
		Terminating i-0c25a87f27b967980
		Removing instances log: ./instances.log
