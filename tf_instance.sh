#!/usr/bin/env bash

# Use AWS CLI to get the most recent version of an AMI that 
# matches certain criteria. Has obvious uses. Made possible via
# --query, --output text, and the fact that RFC3339 datetime
# fields are easily sortable.

set -e

print_usage() {
    echo "USAGE: $0 launch|list|terminate [ubuntu|aws|aws2]"
}

SIZE=t2.micro
LOCAL_KEY=~/.ssh/id_rsa.pub
#SG_NAME=ssh-only-sg

# Pull the region name from the AWS_DEFAULT_REGION if set (else terrafrom.tf defaults to us-east-1)
if [ ! -n $AWS_DEFAULT_REGION ]; then
    $REGION_PARM=" -var \"region=$AWS_DEFAULT_REGION\" "
fi

case $1 in 
    launch )
        # Check to make sure the local ssh key exists
        if [ ! -f $LOCAL_KEY ]; then
            # If not, create it
            ssh-keygen -f id_rsa -t rsa -N ''
        fi
        # Get our public IP address
        MY_IP="`curl -s https://ipinfo.io/ip`/32"
        # Initialize terraform
        terraform init
        # Run the apply
        terraform apply -var "os=$2" -var "allowed_cidrs=$MY_IP" $REGION_PARM -auto-approve
        ;;
    list )
        # List the output vars
        terraform output
        ;;
    terminate )
        # Destroy the resources
        terraform destroy -auto-approve
        # Clean up the state files
        rm -rf .terraform 
        rm terraform.tfstate*
        ;;
esac
