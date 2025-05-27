#!/bin/bash

# Exit on any error
set -e

# Function to print status messages
print_status() {
    echo -e "\n\033[1;34m==>\033[0m $1"
}

# Function to print error messages
print_error() {
    echo -e "\n\033[1;31mError:\033[0m $1"
    exit 1
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if scp is installed
if ! command_exists scp; then
    print_error "scp is not installed. Please install openssh-client: sudo apt-get install openssh-client"
fi

# Check if both scripts exist
if [ ! -f "deploy.sh" ] || [ ! -f "post-deploy.sh" ]; then
    print_error "Both deploy.sh and post-deploy.sh must be in the current directory"
fi

# Get server details
read -p "Enter your droplet IP address: " DROPLET_IP
read -p "Enter your SSH username (default: root): " SSH_USER
SSH_USER=${SSH_USER:-root}

# Make scripts executable locally
chmod +x deploy.sh post-deploy.sh

# Transfer the scripts
print_status "Transferring scripts to $SSH_USER@$DROPLET_IP..."

# Create a temporary directory on the droplet
ssh $SSH_USER@$DROPLET_IP "mkdir -p /tmp/deployment-scripts"

# Copy the scripts
scp deploy.sh post-deploy.sh $SSH_USER@$DROPLET_IP:/tmp/deployment-scripts/

# Move the scripts to the correct location and set permissions
ssh $SSH_USER@$DROPLET_IP "sudo mv /tmp/deployment-scripts/* /root/ && \
    sudo chmod +x /root/deploy.sh /root/post-deploy.sh && \
    sudo rm -rf /tmp/deployment-scripts"

print_status "Scripts have been transferred successfully!"
echo "To deploy:"
echo "1. SSH into your droplet: ssh $SSH_USER@$DROPLET_IP"
echo "2. Run the deploy script as root: sudo /root/deploy.sh"
echo "3. After the deploy script completes, switch to summerfest user: su - summerfest"
echo "4. Run the post-deploy script: /home/summerfest/post-deploy.sh" 