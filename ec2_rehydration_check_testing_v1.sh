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

# Function to get the maximum length of a column
get_max_length() {
    max_length=0
    while IFS= read -r line; do
        length=${#line}
        if (( length > max_length )); then
            max_length=$length
        fi
    done
    echo $max_length
}

# Step 1: List all EC2 instances in an account and capture their AMI and launch time
instances=$(aws --profile "$PROFILE" ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,ImageId,LaunchTime]' --output text)

# Calculate the maximum length for each column
max_id_length=$(echo "$instances" | awk '{print $1}' | get_max_length)
max_ami_length=$(echo "$instances" | awk '{print $2}' | get_max_length)
max_launch_time_length=$(echo "$instances" | awk '{print $3}' | get_max_length)

# Ensure minimum column widths
max_id_length=$((max_id_length > 11 ? max_id_length : 11))
max_ami_length=$((max_ami_length > 10 ? max_ami_length : 10))
max_launch_time_length=$((max_launch_time_length > 11 ? max_launch_time_length : 11))

# Print table header with dynamic spacing
header_footer_line=$(printf '+-%-'$max_id_length's-+-%-'$max_ami_length's-+-%-16s-+-%-'$max_launch_time_length's-+-%-17s-+\n' | tr ' ' '-')
echo "$header_footer_line"
printf "| %-$(($max_id_length+1))s | %-$(($max_ami_length+1))s | %-17s | %-$(($max_launch_time_length+1))s | %-18s |\n" \
       "Instance ID" "Current AMI" "AMI Age (days)" "Launch Time" "Compliance Status"
echo "$header_footer_line"

# Step 2: Iterate through each instance and check AMI dates
while IFS= read -r instance_info; do
    instance_id=$(echo "$instance_info" | awk '{print $1}')
    ami_id=$(echo "$instance_info" | awk '{print $2}')
    launch_time=$(echo "$instance_info" | awk '{print $3}')

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
    printf "| %-$(($max_id_length+1))s | %-$(($max_ami_length+1))s | %16d | %-$(($max_launch_time_length+1))s | %-18s |\n" \
           "$instance_id" "$ami_name" "$ami_age_days" "$launch_time" "$compliance_status"
done <<< "$instances"

# Print table footer with dynamic spacing
echo "$header_footer_line"

# Function to generate the GOLD AMI summary table
generate_gold_ami_summary() {
    local gold_ami="$1"
    local gold_amis=$(aws --profile "$PROFILE" ec2 describe-images --filters "Name=name,Values=$gold_ami*" --query 'Images[*].[Name,CreationDate]' --output text | sort -k2 | tail -n 2)

    # Calculate the maximum length for the AMI name column
    max_ami_name_length=$(echo "$gold_amis" | awk '{print $1}' | get_max_length)
    max_ami_name_length=$((max_ami_name_length > 16 ? max_ami_name_length : 16))

    # Print table header with dynamic spacing for the GOLD AMI summary
    gold_header_footer_line=$(printf '+-%-'$max_ami_name_length's-+-%-11s-+\n' | tr ' ' '-')
    echo "$gold_header_footer_line"
    printf "| %-$(($max_ami_name_length+1))s | %-12s |\n" "GOLD AMI ($gold_ami)" "Age (days)"
    echo "$gold_header_footer_line"

    # Iterate through the GOLD AMIs and calculate their age
    while IFS= read -r ami_info; do
        ami_name=$(echo "$ami_info" | awk '{print $1}')
        ami_creation_date=$(echo "$ami_info" | awk '{print $2}' | awk -F'T' '{print $1}')

        # Convert the AMI creation date to a format that can be used with the 'date' command
        formatted_ami_creation_date=$(date -d "$ami_creation_date" +%Y-%m-%d)

        # Calculate the age of the AMI
        ami_creation_date_seconds=$(date -d "$formatted_ami_creation_date" +%s)
        ami_age_days=$(( ($current_date_seconds - $ami_creation_date_seconds) / 86400 ))

        # Print the summary row for each GOLD AMI
        printf "| %-$(($max_ami_name_length+1))s | %11d |\n" "$ami_name" "$ami_age_days"
    done <<< "$gold_amis"

    # Print table footer with dynamic spacing for the GOLD AMI summary
    echo "$gold_header_footer_line"
}

# Generate GOLD AMI summary tables for each provided AMI
generate_gold_ami_summary "$GOLD_AMI_1"
generate_gold_ami_summary "$GOLD_AMI_2"
