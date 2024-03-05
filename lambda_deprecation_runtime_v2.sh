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

# Print table header with borders
printf "+------------------------------+---------------------+------------------------------+\n"
printf "| %-28s | %-19s | %-28s |\n" "Function Name" "Deprecated Runtime" "Application"
printf "+------------------------------+---------------------+------------------------------+\n"

# List all Lambda functions and check their runtimes and application tags
aws lambda list-functions --profile $AWS_PROFILE --region $AWS_REGION --query "Functions[*].[FunctionName,Runtime]" --output text | while read -r line; do
    function_name=$(echo "$line" | awk '{print $1}')
    runtime=$(echo "$line" | awk '{print $2}')

    if is_runtime_deprecated "$runtime"; then
        # Get the tags for the function
        tags=$(aws lambda list-tags --profile $AWS_PROFILE --region $AWS_REGION --resource "arn:aws:lambda:$AWS_REGION:$AWS_ACCOUNT_ID:function:$function_name" --output text)

        # Extract the "Application System CI Name" tag value
        application_tag=$(echo "$tags" | grep "Application System CI Name" | awk '{print $2}')

        # Print the function details with the application tag and borders
        printf "| %-28s | %-19s | %-28s |\n" "$function_name" "$runtime" "$application_tag"
    fi
done

# Print table footer
printf "+------------------------------+---------------------+------------------------------+\n"