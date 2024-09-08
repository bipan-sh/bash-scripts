#!/bin/bash

# Function to print a separator
separator() {
    echo "-------------------------------------------------"
}

# Display the current user
separator
echo "Current User: $(whoami)"
separator

# Display the system uptime
echo "System Uptime:"
uptime
separator

# Display the current date and time
echo "Current Date and Time:"
date
separator

# Display memory usage (macOS uses 'vm_stat' for memory)
echo "Memory Usage:"
vm_stat | perl -ne '/page size of (\d+)/ and $size=$1; /Pages free:\s+(\d+)/ and printf("Free Memory: %.2f GB\n", $1 * $size / 1024 / 1024 / 1024); /Pages active:\s+(\d+)/ and printf("Active Memory: %.2f GB\n", $1 * $size / 1024 / 1024 / 1024); /Pages inactive:\s+(\d+)/ and printf("Inactive Memory: %.2f GB\n", $1 * $size / 1024 / 1024 / 1024); /Pages speculative:\s+(\d+)/ and printf("Speculative Memory: %.2f GB\n", $1 * $size / 1024 / 1024 / 1024);'
separator

# Display disk usage
echo "Disk Usage:"
df -h
separator

# Display the current logged-in users
echo "Currently Logged-in Users:"
who
separator

# Display system hostname
echo "System Hostname: $(hostname)"
separator

# Display macOS version
echo "macOS Version:"
sw_vers
separator

# Display CPU information (macOS uses 'sysctl' for CPU details)
echo "CPU Information:"
sysctl -n machdep.cpu.brand_string
separator

# Display IP address
echo "Private IP Address:"
ipconfig getifaddr en0
echo "Public IP Address:"
public_ip=$(curl -s https://ifconfig.me)
echo $public_ip
separator

# End of script
echo "System information displayed successfully"