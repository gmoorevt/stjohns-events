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

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root"
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
        cat > /etc/nginx/sites-available/summerfest << 'EOL'
# Frontend
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:80;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}

# Backend API
server {
    listen 80;
    server_name api.your-domain.com;

    location / {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EOL

        # Enable the site
        ln -sf /etc/nginx/sites-available/summerfest /etc/nginx/sites-enabled/
        nginx -t && systemctl restart nginx
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
    
    # Copy the script to summerfest's home directory
    cp "$(dirname "$0")/post-deploy.sh" /home/summerfest/
    
    # Set ownership and permissions
    chown summerfest:summerfest /home/summerfest/post-deploy.sh
    chmod +x /home/summerfest/post-deploy.sh
    
    print_status "Post-deploy script has been copied to /home/summerfest/post-deploy.sh"
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
    
    print_status "Basic server setup complete!"
    print_status "Next steps:"
    echo "1. Update the Nginx configuration with your domain names"
    echo "2. Run certbot to set up SSL: sudo certbot --nginx -d your-domain.com -d api.your-domain.com"
    echo "3. Switch to summerfest user: su - summerfest"
    echo "4. Run the post-deploy script: ./post-deploy.sh"
    echo "5. Monitor the logs: docker compose -f docker-compose.prod.yml logs -f"
}

# Run the deployment
deploy 