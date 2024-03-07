#!/bin/bash

# Check if the correct number of arguments is provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <profile> <gold_ami_1> <gold_ami_2>"
    exit 1
fi

# Set the AWS CLI profile and GOLD AMI variables
PROFILE="$1"
GOLD_AMI_1="$2"
GOLD_AMI_2="$3"

# Define the threshold for rehydration in days
rehydration_threshold=30

# Step 1: List all EC2 instances in an account and capture their AMI and launch time
instances=$(aws --profile "$PROFILE" ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,ImageId,LaunchTime]' --output text)

# Header for the EC2 instance summary table
printf "+-----------------+----------------------+-----------------------+----------------+-------------------+\n"
printf "| Instance ID     | Current AMI          | Launch Time           | AMI Age (days) | Compliance Status |\n"
printf "+-----------------+----------------------+-----------------------+----------------+-------------------+\n"

# Step 2: Iterate through each instance and check AMI dates
while read -r instance_id ami_id launch_time; do
    # Get the AMI name and creation date for the current instance
    ami_info=$(aws --profile "$PROFILE" ec2 describe-images --image-ids $ami_id --query 'Images[*].[Name,CreationDate]' --output text)
    ami_name=$(echo "$ami_info" | cut -f1)
    ami_creation_date=$(echo "$ami_info" | cut -f2)

    # Calculate the age of the current AMI
    ami_creation_date_seconds=$(date -d $ami_creation_date +%s)
    current_date_seconds=$(date +%s)
    ami_age_days=$(( ($current_date_seconds - $ami_creation_date_seconds) / 86400 ))

    # Determine compliance status based on AMI age
    if [ $ami_age_days -le $rehydration_threshold ]; then
        compliance_status="Compliant"
    else
        compliance_status="Non-compliant"
    fi

    # Print the summary row for each instance
    printf "| %-15s | %-20s | %-21s | %-14d | %-17s |\n" "$instance_id" "$ami_name" "$launch_time" "$ami_age_days" "$compliance_status"
done <<< "$instances"

# Footer for the EC2 instance summary table
printf "+-----------------+----------------------+-----------------------+----------------+-------------------+\n"

# Function to generate the GOLD AMI summary table
generate_gold_ami_summary() {
    local gold_ami="$1"
    local gold_amis=$(aws --profile "$PROFILE" ec2 describe-images --filters "Name=name,Values=$gold_ami*" --query 'Images[*].[Name,CreationDate]' --output text | sort -k2)

    # Header for the GOLD AMI summary table
    printf "\n+----------------------+-----------------------+\n"
    printf "| GOLD AMI ($gold_ami)  | Age (days)            |\n"
    printf "+----------------------+-----------------------+\n"

    # Iterate through the GOLD AMIs and calculate their age
    while read -r ami_name ami_creation_date; do
        # Calculate the age of the AMI
        ami_creation_date_seconds=$(date -d $ami_creation_date +%s)
        ami_age_days=$(( ($current_date_seconds - $ami_creation_date_seconds) / 86400 ))

        # Print the summary row for each GOLD AMI
        printf "| %-20s | %-21d |\n" "$ami_name" "$ami_age_days"
    done <<< "$gold_amis"

    # Footer for the GOLD AMI summary table
    printf "+----------------------+-----------------------+\n"
}

# Generate GOLD AMI summary tables for each provided AMI
generate_gold_ami_summary "$GOLD_AMI_1"
generate_gold_ami_summary "$GOLD_AMI_2"
