# Bash Script Repository

This repository contains a collection of Bash scripts that I've created while learning and practicing shell scripting. 

## Table of Contents

- [Overview](#overview)
- [Getting Started](#getting-started)
- [S3 Upload Script](#s3-upload-script)

## Overview

This repository serves as a sandbox for practicing Bash scripting. Each script is designed to solve a specific problem or automate tasks commonly performed in Unix/Linux environments.

## Getting Started

To run these Bash scripts on your local machine, ensure that you have:

- A Unix-based operating system 
- Bash installed (most Unix-based systems come with Bash by default).


### Cloning the Repository

To get started, clone this repository to your local machine:

```bash
git clone https://github.com/bipan-sh/bash-scripts.git
cd bash-scripts
chmod +x <script> 

```

## S3 Upload Script

The `upload_to_s3.sh` script allows you to upload a local directory to an Amazon S3 bucket. The script provides interactive prompts to specify the directory to upload and confirms the size before proceeding.

### Prerequisites

#### 1. Install AWS CLI

Before using the script, you need to install the AWS Command Line Interface (CLI):

**For macOS (using Homebrew):**
```bash
brew install awscli
```

**For macOS (using the official installer):**
```bash
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /
```

**For Debian/Ubuntu Linux:**
```bash
sudo apt update
sudo apt install -y awscli
```

**For Red Hat/CentOS/Fedora Linux:**
```bash
sudo yum install -y awscli
```

**For Windows:**
Download and run the installer from the [official AWS CLI download page](https://aws.amazon.com/cli/).

**Using pip (any platform):**
```bash
pip install awscli
```

#### 2. Configure AWS Credentials

After installing the AWS CLI, configure your credentials:

```bash
aws configure
```

You'll need to enter:
- **AWS Access Key ID**: Your IAM user access key
- **AWS Secret Access Key**: Your IAM user secret key
- **Default region name**: Your preferred AWS region (e.g., us-east-1)
- **Default output format**: Preferred output format (e.g., json)

To obtain these credentials:
1. Log in to the [AWS Management Console](https://aws.amazon.com/console/)
2. Navigate to IAM (Identity and Access Management)
3. Create or select a user with S3 access permissions
4. Generate or retrieve the access keys

### Using the S3 Upload Script

1. Make the script executable:
   ```bash
   chmod +x upload_to_s3.sh
   ```

2. Run the script:
   ```bash
   ./upload_to_s3.sh
   ```

3. Follow the interactive prompts:
   - Enter your S3 bucket name
   - Provide the full path to the directory you want to upload
   - Optionally specify a prefix/folder within the S3 bucket
   - Confirm the upload after seeing the directory size

The script will verify that your AWS CLI is properly configured and that the specified S3 bucket exists before attempting the upload.
