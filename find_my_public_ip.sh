#!/bin/bash

# Check public IP address using ifconfig.me
echo "Fetching public IP address..."
public_ip=$(curl -s https://ifconfig.me)

# Display the public IP address
if [ -n "$public_ip" ]; then
  echo "Your public IP address is: $public_ip"
else
  echo "Failed to fetch public IP address. Check your network connection."
fi

