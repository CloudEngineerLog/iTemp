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

# Prepare the header for the EC2 instance summary table
header="Instance ID | Current AMI | AMI Age (days) | Launch Time | Compliance Status"
echo "$header"

# Prepare the separator line for the header
header_separator=$(printf '%s' "$header" | sed 's/[^|]/-/g')
echo "$header_separator"

# Step 2: Iterate through each instance and check AMI dates
while read -r instance_id ami_id launch_time; do
    # Get the AMI name and creation date for the current instance
    ami_info=$(aws --profile "$PROFILE" ec2 describe-images --image-ids $ami_id --query 'Images[*].[Name,CreationDate]' --output text)
    ami_name=$(echo "$ami_info" | cut -f1)
    ami_creation_date=$(echo "$ami_info" | cut -f2 | awk -F'T' '{print $1}')

    # Convert the AMI creation date to a format that can be used with the 'date' command
    formatted_ami_creation_date=$(date -d "$ami_creation_date" +%Y-%m-%d)

    # Calculate the age of the current AMI
    ami_creation_date_seconds=$(date -d "$formatted_ami_creation_date" +%s)
    current_date_seconds=$(date +%s)
    ami_age_days=$(( ($current_date_seconds - $ami_creation_date_seconds) / 86400 ))

    # Determine compliance status based on AMI age
    if [ $ami_age_days -le $rehydration_threshold ]; then
        compliance_status="Compliant"
    else
        compliance_status="Non-compliant"
    fi

    # Print the summary row for each instance
    printf "%s | %s | %d | %s | %s\n" \
           "$instance_id" "$ami_name" "$ami_age_days" "$launch_time" "$compliance_status"
done <<< "$instances" | column -t -s '|'

echo "$header_separator"

# Function to generate the GOLD AMI summary table
generate_gold_ami_summary() {
    local gold_ami="$1"
    local gold_amis=$(aws --profile "$PROFILE" ec2 describe-images --filters "Name=name,Values=$gold_ami*" --query 'Images[*].[Name,CreationDate]' --output text | sort -k2 | tail -n 2)

    # Header for the GOLD AMI summary table
    echo "GOLD AMI ($gold_ami) | Age (days)"
    echo "---------------------|-----------"

    # Iterate through the GOLD AMIs and calculate their age
    while read -r ami_name ami_creation_date; do
        # Convert the AMI creation date to a format that can be used with the 'date' command
        formatted_ami_creation_date=$(date -d "$ami_creation_date" +%Y-%m-%d)

        # Calculate the age of the AMI
        ami_creation_date_seconds=$(date -d "$formatted_ami_creation_date" +%s)
        ami_age_days=$(( ($current_date_seconds - $ami_creation_date_seconds) / 86400 ))

        # Print the summary row for each GOLD AMI
        printf "%s | %d\n" "$ami_name" "$ami_age_days"
    done <<< "$gold_amis" | column -t -s '|'

    echo "---------------------|-----------"
}

# Generate GOLD AMI summary tables for each provided AMI
generate_gold_ami_summary "$GOLD_AMI_1"
generate_gold_ami_summary "$GOLD_AMI_2"
