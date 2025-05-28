#!/bin/bash

# Exit on any error
set -e

# Print status messages
print_status() {
    echo "==> $1"
}

print_error() {
    echo "ERROR: $1" >&2
}

# Check if scp is installed
if ! command -v scp &> /dev/null; then
    print_error "scp is not installed. Please install it first."
    exit 1
fi

# Check if deploy-production.sh exists
if [ ! -f "deploy-production.sh" ]; then
    print_error "deploy-production.sh not found in current directory"
    exit 1
fi

# Get server details
read -p "Enter your Digital Ocean droplet IP address: " SERVER_IP
read -p "Enter your SSH username (default: root): " SSH_USER
SSH_USER=${SSH_USER:-root}

# Transfer the file
print_status "Transferring deploy-production.sh to server..."
scp deploy-production.sh ${SSH_USER}@${SERVER_IP}:/root/deploy-production.sh

# Make it executable on the server
print_status "Making deploy-production.sh executable on the server..."
ssh ${SSH_USER}@${SERVER_IP} "chmod +x /root/deploy-production.sh"

print_status "Transfer complete!"
echo
echo "The deployment script has been transferred to your server at:"
echo "/root/deploy-production.sh"
echo
echo "To deploy the application:"
echo "1. SSH into your server: ssh ${SSH_USER}@${SERVER_IP}"
echo "2. Run the deployment script as root: ./deploy-production.sh"
echo
echo "The script will:"
echo "- Install all required packages (Docker, Nginx, etc.)"
echo "- Set up the summerfest user and directories"
echo "- Configure Nginx with your domains"
echo "- Clone the repository"
echo "- Deploy the application"
echo
echo "Note: You will be prompted to enter your domain names when running the script." 