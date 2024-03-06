#!/bin/bash

# Check if the required arguments are provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 <region> <profile>"
    exit 1
fi

region=$1
profile=$2

echo "Region, VPC ID, Subnet ID, Auto-assign Public IPv4"
echo "--------------------------------------------------"

# Get the list of subnets in the specified region and profile
subnets=$(aws ec2 describe-subnets --region "$region" --profile "$profile" --query "Subnets[*].{SubnetId:SubnetId, VpcId:VpcId, MapPublicIpOnLaunch:MapPublicIpOnLaunch}" --output text)

# Create a temporary file to store the output
temp_file=$(mktemp)

# Iterate over each subnet and check if auto-assign public IP is enabled
while read -r subnet; do
    subnet_id=$(echo $subnet | awk '{print $1}')
    vpc_id=$(echo $subnet | awk '{print $2}')
    auto_assign_public_ip=$(echo $subnet | awk '{print $3}')
    
    if [[ $auto_assign_public_ip == "True" ]]; then
        echo "$region, $vpc_id, $subnet_id, $auto_assign_public_ip" >> "$temp_file"
    fi
done <<< "$subnets"

# Format the output as a table
column -t -s, "$temp_file"

# Remove the temporary file
rm "$temp_file"