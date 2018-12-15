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

if [ ! -n $AWS_DEFAULT_REGION ]; then
    $REGION_PARM=" -var \"region=$AWS_DEFAULT_REGION\" "
fi

case $1 in 
    launch )
        MY_IP="`curl -s https://ipinfo.io/ip`/32"
        terraform init
        terraform apply -var "os=$2" -var "allowed_cidrs=$MY_IP" $REGION_PARM -auto-approve
        ;;
    list )
        terraform output
        ;;
    terminate )
        terraform destroy -auto-approve
        ;;
esac
