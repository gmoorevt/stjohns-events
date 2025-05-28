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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root"
    exit 1
fi

# Get domain names
get_domain_names() {
    echo
    echo "Please enter your domain names:"
    read -p "Main domain (e.g., summerfest.com): " MAIN_DOMAIN
    read -p "API subdomain (e.g., api.summerfest.com): " API_DOMAIN
    
    # Validate domain names
    if [[ -z "$MAIN_DOMAIN" || -z "$API_DOMAIN" ]]; then
        print_error "Domain names cannot be empty"
        exit 1
    fi
    
    # Export for use in other functions
    export MAIN_DOMAIN
    export API_DOMAIN
}

# Install required packages
install_packages() {
    print_status "Updating package lists..."
    apt update

    print_status "Installing required packages..."
    apt install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        software-properties-common \
        git \
        nginx \
        python3-pip \
        python3-venv

    # Install Docker
    if ! command -v docker &> /dev/null; then
        print_status "Installing Docker..."
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
        add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        apt update
        apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        systemctl start docker
        systemctl enable docker
    else
        print_status "Docker is already installed"
    fi

    # Install Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_status "Installing Docker Compose..."
        curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    else
        print_status "Docker Compose is already installed"
    fi
}

# Create summerfest user and setup
setup_user() {
    if ! id "summerfest" &>/dev/null; then
        print_status "Creating summerfest user..."
        adduser --disabled-password --gecos "" summerfest
        usermod -aG docker summerfest
        usermod -aG sudo summerfest
        
        # Set up SSH directory and authorized_keys
        mkdir -p /home/summerfest/.ssh
        chmod 700 /home/summerfest/.ssh
        touch /home/summerfest/.ssh/authorized_keys
        chmod 600 /home/summerfest/.ssh/authorized_keys
        chown -R summerfest:summerfest /home/summerfest/.ssh
    else
        print_status "summerfest user already exists"
    fi
}

# Setup application directory
setup_application() {
    APP_DIR="/home/summerfest/stjohns-events"
    print_status "Setting up application directory..."
    
    # Create necessary directories
    mkdir -p $APP_DIR
    mkdir -p $APP_DIR/backend/data
    mkdir -p /home/summerfest/backups
    
    # Set permissions
    chown -R summerfest:summerfest $APP_DIR
    chown -R summerfest:summerfest /home/summerfest/backups
    chmod 755 $APP_DIR
}

# Configure Nginx
setup_nginx() {
    print_status "Setting up Nginx configuration..."
    
    # Create Nginx configuration
    cat > /etc/nginx/sites-available/summerfest << EOL
# Frontend
server {
    listen 80;
    server_name ${MAIN_DOMAIN};

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
    server_name ${API_DOMAIN};

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

    # Enable the site
    ln -sf /etc/nginx/sites-available/summerfest /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default

    # Test Nginx configuration
    print_status "Testing Nginx configuration..."
    nginx -t

    # Start Nginx
    systemctl start nginx
    systemctl enable nginx
}

# Create docker-compose.prod.yml
create_docker_compose() {
    print_status "Creating docker-compose.prod.yml..."
    cat > /home/summerfest/stjohns-events/docker-compose.prod.yml << 'EOL'
version: '3.8'

services:
  backend:
    build:
      context: ./backend
      target: production
    container_name: summerfest-backend
    volumes:
      - backend_data:/app/data
    ports:
      - "8000:8000"
    environment:
      - ENVIRONMENT=production
      - EVENTBRITE_API_KEY=${EVENTBRITE_API_KEY}
      - EVENTBRITE_CLIENT_SECRET=${EVENTBRITE_CLIENT_SECRET}
      - EVENTBRITE_PRIVATE_TOKEN=${EVENTBRITE_PRIVATE_TOKEN}
      - EVENTBRITE_PUBLIC_TOKEN=${EVENTBRITE_PUBLIC_TOKEN}
    restart: unless-stopped
    networks:
      - app-network

  frontend:
    container_name: summerfest-frontend
    build:
      context: ./frontend
      target: production
    ports:
      - "3000:80"
    depends_on:
      - backend
    restart: unless-stopped
    networks:
      - app-network

volumes:
  backend_data:

networks:
  app-network:
    driver: bridge
EOL

    chown summerfest:summerfest /home/summerfest/stjohns-events/docker-compose.prod.yml
}

# Create .env template
create_env_template() {
    print_status "Creating .env template..."
    cat > /home/summerfest/stjohns-events/.env.template << EOL
# Eventbrite API Credentials
EVENTBRITE_API_KEY=your_api_key_here
EVENTBRITE_CLIENT_SECRET=your_client_secret_here
EVENTBRITE_PRIVATE_TOKEN=your_private_token_here
EVENTBRITE_PUBLIC_TOKEN=your_public_token_here
EVENTBRITE_OAUTH_TOKEN=your_oauth_token_here
EVENTBRITE_ORG_ID=your_org_id_here

# Backend Environment Variables
BACKEND_CORS_ORIGINS=http://localhost:5173,http://frontend:5173,https://${MAIN_DOMAIN}
ENVIRONMENT=production

# Frontend Environment Variables
VITE_API_URL=https://${API_DOMAIN}
NODE_ENV=production
EOL

    chown summerfest:summerfest /home/summerfest/stjohns-events/.env.template
}

# Clone repository
clone_repository() {
    print_status "Cloning repository..."
    cd /home/summerfest/stjohns-events
    
    # Backup any existing .env files
    if [ -f .env ]; then
        print_status "Backing up existing .env file..."
        mv .env .env.backup
    fi
    if [ -f backend/.env ]; then
        print_status "Backing up existing backend/.env file..."
        mv backend/.env backend/.env.backup
    fi
    if [ -f frontend/.env ]; then
        print_status "Backing up existing frontend/.env file..."
        mv frontend/.env frontend/.env.backup
    fi
    
    # Remove existing files except backups
    print_status "Cleaning up existing files..."
    find . -mindepth 1 -not -name "*.backup" -not -name ".*" -exec rm -rf {} +
    
    # Clone the repository
    print_status "Cloning fresh copy of repository..."
    git clone https://github.com/gmoorevt/stjohns-events.git temp_repo
    mv temp_repo/* temp_repo/.* .
    rm -rf temp_repo
    
    # Restore .env files if they exist
    if [ -f .env.backup ]; then
        print_status "Restoring .env file..."
        mv .env.backup .env
    fi
    if [ -f backend/.env.backup ]; then
        print_status "Restoring backend/.env file..."
        mv backend/.env.backup backend/.env
    fi
    if [ -f frontend/.env.backup ]; then
        print_status "Restoring frontend/.env file..."
        mv frontend/.env.backup frontend/.env
    fi
    
    # Set proper ownership
    chown -R summerfest:summerfest /home/summerfest/stjohns-events
}

# Setup environment files
setup_environment() {
    print_status "Setting up environment files..."
    cd /home/summerfest/stjohns-events
    
    # Create .env files from template if they don't exist
    for env_file in .env backend/.env frontend/.env; do
        if [ ! -f "$env_file" ]; then
            cp .env.template "$env_file"
        fi
    done
    
    # Set proper ownership
    chown -R summerfest:summerfest /home/summerfest/stjohns-events
}

# Deploy application
deploy_application() {
    print_status "Deploying application..."
    cd /home/summerfest/stjohns-events
    
    # Stop any running containers
    docker-compose -f docker-compose.prod.yml down || true
    
    # Start the application
    docker-compose -f docker-compose.prod.yml up -d --build
    
    # Verify services are running
    print_status "Verifying services..."
    sleep 5
    if docker ps | grep -q "summerfest-frontend" && docker ps | grep -q "summerfest-backend"; then
        print_status "Deployment successful! Services are running."
    else
        print_error "Deployment may have issues. Please check the logs:"
        echo "docker-compose -f docker-compose.prod.yml logs"
    fi
}

# Main deployment process
main() {
    print_status "Starting deployment process..."
    
    # Get domain names
    get_domain_names
    
    # Install required packages
    install_packages
    
    # Setup user and directories
    setup_user
    setup_application
    
    # Configure Nginx
    setup_nginx
    
    # Create configuration files
    create_docker_compose
    create_env_template
    
    # Clone and setup repository
    clone_repository
    setup_environment
    
    # Deploy application
    deploy_application
    
    print_status "Deployment process complete!"
    echo
    echo "Next steps:"
    echo "1. Configure your DNS records to point to this server:"
    echo "   - ${MAIN_DOMAIN} -> Your server IP"
    echo "   - ${API_DOMAIN} -> Your server IP"
    echo "2. Update the .env files with your actual credentials:"
    echo "   - /home/summerfest/stjohns-events/.env"
    echo "   - /home/summerfest/stjohns-events/backend/.env"
    echo "   - /home/summerfest/stjohns-events/frontend/.env"
    echo "3. Set up SSL certificates:"
    echo "   sudo apt install -y certbot python3-certbot-nginx"
    echo "   sudo certbot --nginx -d ${MAIN_DOMAIN} -d ${API_DOMAIN}"
    echo
    echo "To check the application status:"
    echo "docker ps"
    echo "docker-compose -f /home/summerfest/stjohns-events/docker-compose.prod.yml logs"
}

# Run the deployment
main 