#!/usr/bin/env bash

# Use AWS CLI to get the most recent version of an AMI that 
# matches certain criteria. Has obvious uses. Made possible via
# --query, --output text, and the fact that RFC3339 datetime
# fields are easily sortable.

set -e

print_usage() {
    echo "USAGE: $0 launch|terminate [ubuntu|aws|aws2]"
}

SIZE=t2.micro
LOCAL_KEY=~/.ssh/id_rsa.pub
INSTANCES_LOG=./instances.log

case $1 in 
    launch )
        echo "Launching (1) $2 instance size: $SIZE in $AWS_DEFAULT_REGION"
        case $2 in 
            ubuntu )
                NAME=ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-*-amd64-server*
                USER=ubuntu
                ;;
            aws )
                NAME=amzn-ami-hvm-*-x86_64-gp2
                USER=ec2-user
                ;;
            aws2 )
                NAME=amzn2-ami-hvm-2.0.*-x86_64-gp2
                USER=ec2-user
                ;;
            * )
                print_usage
                exit 1
                ;;
        esac
        echo -n "Looking up latest AMI for $2... "
        AMI=`aws ec2 describe-images \
            --filters Name=name,Values="$NAME" \
            --query 'sort_by(Images, &CreationDate)[-1].ImageId' \
            | sed s/\"//g`
        echo "found: $AMI"
        HOSTNAME=`uname -n`

        if [ `aws ec2 describe-key-pairs | jq .KeyPairs[].KeyName | grep -c $HOSTNAME` -lt 1 ]; then
            if [ ! -f $LOCAL_KEY ]; then
                echo "Creating local ssh keypair"
                ssh-keygen -f id_rsa -t rsa -N ''
            fi
            "Importing local keypair ~/.ssh/id_rsa.pub into aws keypair name $HOSTNAME"
            aws ec2 import-key-pair \
                --key-name $HOSTNAME \
                --public-key-material file://$LOCAL_KEY
        else
            echo "Using existing AWS key name: $HOSTNAME"
        fi
        # Launch the instance
        echo -n "Launching instance id: "
        INSTANCE=`aws ec2 run-instances \
            --image-id $AMI \
            --instance-type t2.micro \
            --key-name $HOSTNAME`
        # Get the instance ID
        INSTANCE_ID=`echo $INSTANCE | jq -r .Instances[].InstanceId`
        echo $INSTANCE_ID
        echo $INSTANCE_ID >> $INSTANCES_LOG
        # Get the public IP
        PUBLIC_IP=`aws ec2 describe-instances \
            --instance-id $INSTANCE_ID \
            | jq -r .Reservations[0].Instances[0].PublicIpAddress`
        while [ $PUBLIC_IP == "null" ]; do
            PUBLIC_IP=`aws ec2 describe-instances \
                --instance-id $INSTANCE_ID \
                | jq -r .Reservations[0].Instances[0].PublicIpAddress`
            sleep 5
        done
        echo "Connect with: ssh -i $LOCAL_KEY $USER@$PUBLIC_IP"
        ;;

    terminate )
        # Look up the list of instances created with this tool
        for INSTANCE_ID in `cat instances.log`; do
            # Terminate each
            echo "Terminating $INSTANCE_ID"
            aws ec2 terminate-instances --instance-id $INSTANCE_ID
        done
        # Remove the instances.log file
        echo "Removing instances log: $INSTANCES_LOG"
        rm $INSTANCES_LOG
        ;;
    * )
        print_usage
        exit 1
        ;;
    esac
