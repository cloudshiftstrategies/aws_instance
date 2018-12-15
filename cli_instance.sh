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
INSTANCES_LOG=./instances.log
SG_NAME=ssh-only-sg

case $1 in 
    launch )
        echo "Launching (1) $2 instance size: $SIZE in $AWS_DEFAULT_REGION"
        case $2 in 
            ubuntu )
                NAME=ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server*
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

        # Find or create the ssh keypair
        HOSTNAME=`uname -n`

        if [ `aws ec2 describe-key-pairs | jq .KeyPairs[].KeyName | grep -c $HOSTNAME` -lt 1 ]; then
            if [ ! -f $LOCAL_KEY ]; then
                echo "Creating local ssh keypair"
                ssh-keygen -f id_rsa -t rsa -N ''
            fi
            echo "Importing local public key: $LOCAL_KEY into aws as key-name: $HOSTNAME"
            aws ec2 import-key-pair \
                --key-name $HOSTNAME \
                --public-key-material file://$LOCAL_KEY > /dev/null
        else
            echo "Using existing AWS key name: $HOSTNAME"
        fi

        # Find the default vpc
        DEFAULT_VPC=`aws ec2 describe-vpcs | jq -r '.Vpcs[] | select(.IsDefault==true) | .VpcId'`

        # Find or create the security group ssh-only
        if [ `aws ec2 describe-security-groups --filter Name=vpc-id,Values=$DEFAULT_VPC | jq -r .SecurityGroups[].GroupName | grep -c $SG_NAME` -lt 1 ]; then
            # The security group doesnt exist.. create it
            echo "Creating security group $SG_NAME in default vpc: $DEFAULT_VPC"
            aws ec2 create-security-group \
                --group-name $SG_NAME \
                --description "SSH Only Security Group for default vpc" \
                --vpc-id $DEFAULT_VPC > /dev/null
        fi
        # Lookup security Group ID with $SG_NAME and in default VPC
        SG_ID=`aws ec2 describe-security-groups \
            --filter Name=group-name,Values=$SG_NAME \
            --filter Name=vpc-id,Values=$DEFAULT_VPC \
            | jq -r .SecurityGroups[0].GroupId`
        echo "Found Security Group name: $SG_NAME as ID : $SG_ID"

        # Add rule to security group
        MY_IP="`curl -s https://ipinfo.io/ip`/32"
        if [ -n `aws ec2 describe-security-groups \
            --filter Name=group-name,Values=ssh-only-sg \
            | jq --arg ip "$MY_IP" '.SecurityGroups[0].IpPermissions[] | select((.FromPort==22) and (.ToPort=22) and (.IpProtocol=="tcp") and (.IpRanges[0].CidrIp==$ip)) | length'` ]; then
            echo "Adding inbound ssh rule from IP $MY_IP to Security Group: $SG_NAME"
            aws ec2 authorize-security-group-ingress \
                --group-id $SG_ID \
                --protocol tcp \
                --port 22 \
                --cidr $MY_IP
        else
            echo "Inbound ssh rule from IP $MY_IP to Security Group: $SG_NAME already exists"
        fi

        # Launch the instance
        echo -n "Launching instance id: "
        INSTANCE=`aws ec2 run-instances \
            --image-id $AMI \
            --instance-type t2.micro \
            --security-groups $SG_NAME \
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

    list )
        # Get Instance public IP(s)
        for INSTANCE_ID in `cat instances.log`; do
            echo -n "$INSTANCE_ID : "
            aws ec2 describe-instances \
                --instance-id $INSTANCE_ID \
                | jq -r .Reservations[0].Instances[0].PublicIpAddress
        done
        ;;

    terminate )
        # Look up the list of instances created with this tool
        for INSTANCE_ID in `cat instances.log`; do
            # Terminate each
            echo "Terminating $INSTANCE_ID"
            aws ec2 terminate-instances --instance-id $INSTANCE_ID > /dev/null
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
