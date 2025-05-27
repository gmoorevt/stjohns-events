#!/bin/bash

# Exit on any error
set -e

# Function to print status messages
print_status() {
    echo -e "\n\033[1;34m==>\033[0m \033[1m$1\033[0m"
}

# Function to print error messages
print_error() {
    echo -e "\n\033[1;31m==>\033[0m \033[1mError: $1\033[0m"
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install Docker if not present
install_docker() {
    if ! command_exists docker; then
        print_status "Installing Docker..."
        apt update && apt upgrade -y
        apt install -y docker.io docker-compose
        systemctl enable docker
        systemctl start docker
    else
        print_status "Docker is already installed"
    fi
}

# Function to create summerfest user
create_user() {
    if ! id "summerfest" &>/dev/null; then
        print_status "Creating summerfest user..."
        adduser --gecos "" --disabled-password summerfest
        usermod -aG docker summerfest
    else
        print_status "User summerfest already exists"
    fi
}

# Function to set up directories and permissions
setup_directories() {
    print_status "Setting up directories and permissions..."
    
    # Create application directory
    mkdir -p /home/summerfest/stjohns-events
    mkdir -p /home/summerfest/stjohns-events/backend/data
    mkdir -p /home/summerfest/backups
    
    # Set ownership
    chown -R summerfest:summerfest /home/summerfest/stjohns-events
    chown -R summerfest:summerfest /home/summerfest/backups
    
    # Set permissions
    chmod 755 /home/summerfest/stjohns-events
    chmod 755 /home/summerfest/backups
    chmod 755 /home/summerfest/stjohns-events/backend/data
}

# Function to install Nginx
install_nginx() {
    if ! command_exists nginx; then
        print_status "Installing Nginx..."
        apt install -y nginx
        
        # Create Nginx configuration
        cat > /tmp/summerfest << EOL
# Frontend
server {
    listen 80;
    server_name \$DOMAIN_NAME;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}

# Backend API
server {
    listen 80;
    server_name api.\$DOMAIN_NAME;

    location / {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOL

        # Move configuration to Nginx sites-available
        sudo mv /tmp/summerfest /etc/nginx/sites-available/summerfest

        # Create symbolic link if it doesn't exist
        if [ ! -L /etc/nginx/sites-enabled/summerfest ]; then
            sudo ln -s /etc/nginx/sites-available/summerfest /etc/nginx/sites-enabled/
        fi

        # Test Nginx configuration
        if ! sudo nginx -t; then
            print_error "Nginx configuration test failed"
            exit 1
        fi

        # Reload Nginx
        sudo systemctl reload nginx
        print_status "Nginx configuration updated successfully"
    else
        print_status "Nginx is already installed"
    fi
}

# Function to install Certbot
install_certbot() {
    if ! command_exists certbot; then
        print_status "Installing Certbot..."
        apt install -y certbot python3-certbot-nginx
    else
        print_status "Certbot is already installed"
    fi
}

# Function to create backup script
create_backup_script() {
    print_status "Creating backup script..."
    
    cat > /home/summerfest/backup.sh << 'EOL'
#!/bin/bash
BACKUP_DIR="/home/summerfest/backups"
mkdir -p $BACKUP_DIR
docker compose -f docker-compose.prod.yml exec backend sqlite3 /app/data/summerfest.db ".backup '$BACKUP_DIR/summerfest-$(date +%Y%m%d).db'"
EOL

    chmod +x /home/summerfest/backup.sh
    chown summerfest:summerfest /home/summerfest/backup.sh
    
    # Add to crontab if not already present
    (crontab -u summerfest -l 2>/dev/null | grep -q "backup.sh") || \
    (crontab -u summerfest -l 2>/dev/null; echo "0 2 * * * /home/summerfest/backup.sh") | crontab -u summerfest -
}

# Function to configure firewall
configure_firewall() {
    print_status "Configuring firewall..."
    ufw allow ssh
    ufw allow http
    ufw allow https
    ufw --force enable
}

# Function to set up post-deploy script
setup_post_deploy_script() {
    print_status "Setting up post-deploy script..."
    
    # Copy post-deploy.sh to summerfest user's home directory
    cp post-deploy.sh /home/summerfest/
    sudo chown summerfest:summerfest /home/summerfest/post-deploy.sh
    sudo chmod +x /home/summerfest/post-deploy.sh
    
    print_status "Post-deploy script setup complete"
}

# Main deployment function
deploy() {
    print_status "Starting deployment..."
    
    # Check if running as root
    check_root
    
    # Install required packages
    install_docker
    install_nginx
    install_certbot
    
    # Create user and set up directories
    create_user
    setup_directories
    
    # Configure firewall
    configure_firewall
    
    # Create backup script
    create_backup_script
    
    # Set up post-deploy script
    setup_post_deploy_script
    
    print_status "Deployment completed successfully!"
    echo -e "\nNext steps:"
    echo "1. Switch to summerfest user: su - summerfest"
    echo "2. Run the post-deploy script: ./post-deploy.sh"
    echo "3. Update your domain name in /etc/nginx/sites-available/summerfest"
    echo "4. Run 'sudo nginx -t' to test the configuration"
    echo "5. Run 'sudo systemctl reload nginx' to apply changes"
}

# Run the deployment
deploy 