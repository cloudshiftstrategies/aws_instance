# aws_instance project

Very simple tool for launching a quick EC2 instance without having to go to AWS console

* launch:
	*	Creates an ssh-key names after the local host name (if required)
	*	Launches a linux t2.micro instance of type ubuntu, aws or aws2
	*	Stores the instance ids launched  in the instances.log file
	* Provide connection instructions

* terminate:
	*	Terminates all of the ec2 instances in instances.log
	* deletes instances.log

## Requirements

bash
awscli
openssh

## Usage

		USAGE: ./instance.sh launch|terminate [ubuntu|aws|aws2]

## Example usage

Launch an aws linux 2 instance in the current region (defined by AWS_DEFAULT_REGION env var)

		$ ./instance.sh launch aws2
		Launching (1) aws2 instance size: t2.micro in us-east-1
		Looking up latest AMI for aws2... found: ami-009d6802948d06e52
		Using existing AWS key name: peterb154-asus-laptop
		Launching instance id: i-0c25a87f27b967980
		Connect with: ssh -i /home/peterb154/.ssh/id_rsa.pub ec2-user@54.81.198.132

Terminate all launched instances

		$ ./instance.sh terminate
		Terminating i-0c25a87f27b967980
		{
				"TerminatingInstances": [
						{
								"InstanceId": "i-0c25a87f27b967980",
								"CurrentState": {
										"Code": 32,
										"Name": "shutting-down"
								},
								"PreviousState": {
										"Code": 16,
										"Name": "running"
								}
						}
				]
		}
		Removing instances log: ./instances.log
