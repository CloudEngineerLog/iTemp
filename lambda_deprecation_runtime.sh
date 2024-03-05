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

# List all Lambda functions and check their runtimes
aws lambda list-functions --profile $AWS_PROFILE --region $AWS_REGION --query "Functions[*].[FunctionName,Runtime]" --output text | while read -r line; do
    function_name=$(echo "$line" | awk '{print $1}')
    runtime=$(echo "$line" | awk '{print $2}')

    if is_runtime_deprecated "$runtime"; then
        echo "Deprecated runtime detected: $function_name ($runtime)"
    fi
done