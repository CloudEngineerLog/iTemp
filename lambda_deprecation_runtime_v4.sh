#!/bin/bash

# Default values for AWS profile and region
AWS_PROFILE="default"
AWS_REGION="us-east-1"

# Parse command-line flags for profile and region
while getopts "p:r:" flag; do
    case "${flag}" in
        p) AWS_PROFILE=${OPTARG} ;;
        r) AWS_REGION=${OPTARG} ;;
        *) echo "Usage: $0 [-p aws_profile] [-r aws_region]" >&2
           exit 1 ;;
    esac
done

# Get the AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --profile $AWS_PROFILE --query "Account" --output text)

# List of deprecated runtimes (update this list as needed)
DEPRECATED_RUNTIMES=("nodejs6.10" "python2.7" "dotnetcore2.0")

# Function to check if a runtime is deprecated
is_runtime_deprecated() {
    local runtime=$1
    for deprecated_runtime in "${DEPRECATED_RUNTIMES[@]}"; do
        if [[ "$runtime" == "$deprecated_runtime" ]]; then
            return 0
        fi
    done
    return 1
}

# Function to get the maximum length of function names
get_max_length() {
    max_length=0
    while read -r line; do
        length=${#line}
        if (( length > max_length )); then
            max_length=$length
        fi
    done
    echo $max_length
}

# Initialize counters for each deprecated runtime
declare -A runtime_counters
for runtime in "${DEPRECATED_RUNTIMES[@]}"; do
    runtime_counters[$runtime]=0
done

# Get the list of function names and runtimes
functions_and_runtimes=$(aws lambda list-functions --profile $AWS_PROFILE --region $AWS_REGION --query "Functions[*].[FunctionName,Runtime]" --output text)

# Calculate the maximum length of function names
max_name_length=$(echo "$functions_and_runtimes" | awk '{print $1}' | get_max_length)
name_column_width=$((max_name_length > 28 ? max_name_length : 28)) # Ensure a minimum width of 28

# Print table header with dynamic spacing
printf "+-%-${name_column_width}s-+---------------------+------------------------------+\n" "------------------------------"
printf "| %-$(($name_column_width+1))s | %-19s | %-28s |\n" "Function Name" "Deprecated Runtime" "Application"
printf "+-%-${name_column_width}s-+---------------------+------------------------------+\n" "------------------------------"

# Initialize counter for total deprecated functions
total_deprecated=0

# Print table rows with dynamic spacing for function names
echo "$functions_and_runtimes" | while read -r line; do
    function_name=$(echo "$line" | awk '{print $1}')
    runtime=$(echo "$line" | awk '{print $2}')

    if is_runtime_deprecated "$runtime"; then
        ((total_deprecated++))
        ((runtime_counters[$runtime]++))

        # Get the "Application System CI Name" tag value for the function
        application_tag=$(aws lambda list-tags --profile $AWS_PROFILE --region $AWS_REGION --resource "arn:aws:lambda:$AWS_REGION:$AWS_ACCOUNT_ID:function:$function_name" --output text | grep "Application System CI Name" | awk -F': ' '{print $2}' | sed 's/,$//')

        # Print the function details with dynamic spacing
        printf "| %-$(($name_column_width+1))s | %-19s | %-28s |\n" "$function_name" "$runtime" "$application_tag"
    fi
done

# Print table footer with dynamic spacing
printf "+-%-${name_column_width}s-+---------------------+------------------------------+\n" "------------------------------"

# Print summary
echo -e "\nSummary:"
echo "Total Deprecated Functions: $total_deprecated"
for runtime in "${DEPRECATED_RUNTIMES[@]}"; do
    echo "Count for $runtime: ${runtime_counters[$runtime]}"
done