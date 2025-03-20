#!/bin/bash

# Script to upload a directory to an S3 bucket

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it first."
    echo "You can install it using: pip install awscli"
    exit 1
fi

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "AWS CLI is not configured. Please run 'aws configure' first."
    exit 1
fi

# Prompt for the S3 bucket name
read -p "Enter the S3 bucket name: " BUCKET_NAME

# Validate bucket name
if [ -z "$BUCKET_NAME" ]; then
    echo "Error: S3 bucket name cannot be empty."
    exit 1
fi

# Check if the bucket exists
if ! aws s3 ls "s3://$BUCKET_NAME" &> /dev/null; then
    echo "Error: Bucket '$BUCKET_NAME' does not exist or you don't have permission to access it."
    exit 1
fi

# Prompt for the directory path to upload
read -p "Please provide the full path of the directory you want to upload: " DIRECTORY_PATH

# Validate directory path
if [ ! -d "$DIRECTORY_PATH" ]; then
    echo "Error: '$DIRECTORY_PATH' is not a valid directory."
    exit 1
fi

# Optional: prompt for a prefix (folder) in the S3 bucket
read -p "Enter the S3 prefix/folder (leave empty for root): " S3_PREFIX

# Calculate directory size
DIR_SIZE=$(du -sh "$DIRECTORY_PATH" | cut -f1)

# Ask for confirmation
read -p "This directory is $DIR_SIZE in size, do you want to proceed [Y/N]: " CONFIRM

# Check confirmation
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Upload cancelled."
    exit 0
fi

# Prepare the S3 destination
if [ -z "$S3_PREFIX" ]; then
    S3_DESTINATION="s3://$BUCKET_NAME/"
else
    # Make sure the prefix ends with a slash
    S3_PREFIX="${S3_PREFIX%/}/"
    S3_DESTINATION="s3://$BUCKET_NAME/$S3_PREFIX"
fi

echo "Starting upload to $S3_DESTINATION..."

# Perform the upload
aws s3 cp "$DIRECTORY_PATH" "$S3_DESTINATION" --recursive

# Check if upload was successful
if [ $? -eq 0 ]; then
    echo "Upload completed successfully!"
else
    echo "Upload failed with error code $?."
fi
