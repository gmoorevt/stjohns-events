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

# Check if required files exist
if [ ! -f "deploy.sh" ]; then
    print_error "deploy.sh not found in current directory"
    exit 1
fi

if [ ! -f "post-deploy.sh" ]; then
    print_error "post-deploy.sh not found in current directory"
    exit 1
fi

# Get server details
read -p "Enter your server IP address: " SERVER_IP
read -p "Enter your SSH username (default: root): " SSH_USER
SSH_USER=${SSH_USER:-root}

# Create a temporary directory on the server
print_status "Creating temporary directory on server..."
ssh ${SSH_USER}@${SERVER_IP} "mkdir -p /tmp/summerfest-deploy"

# Transfer the files
print_status "Transferring files to server..."
scp deploy.sh post-deploy.sh ${SSH_USER}@${SERVER_IP}:/tmp/summerfest-deploy/

# Move files to correct location and set permissions
print_status "Setting up files on server..."
ssh ${SSH_USER}@${SERVER_IP} "bash -c '
    # Move deploy.sh to root directory
    mv /tmp/summerfest-deploy/deploy.sh /root/deploy.sh
    chmod +x /root/deploy.sh

    # Create application directory if it doesn'\''t exist
    mkdir -p /home/summerfest/stjohns-events

    # Move post-deploy.sh to application directory
    mv /tmp/summerfest-deploy/post-deploy.sh /home/summerfest/stjohns-events/post-deploy.sh
    chmod +x /home/summerfest/stjohns-events/post-deploy.sh

    # Set ownership
    chown -R summerfest:summerfest /home/summerfest/stjohns-events

    # Clean up
    rm -rf /tmp/summerfest-deploy
'"

print_status "Transfer complete!"
echo
echo "The files have been transferred to your server:"
echo "- /root/deploy.sh"
echo "- /home/summerfest/stjohns-events/post-deploy.sh"
echo
echo "To run the deployment:"
echo "1. SSH into your server: ssh ${SSH_USER}@${SERVER_IP}"
echo "2. Run the deploy script as root: ./deploy.sh"
echo
echo "Note: The post-deploy script will be run automatically by the deploy script." 