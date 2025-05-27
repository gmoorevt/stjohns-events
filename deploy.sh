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

# Function to get domain names
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

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root"
    exit 1
fi

# Get domain names before proceeding
get_domain_names

# Function to install Docker if not present
install_docker() {
    if ! command -v docker &> /dev/null; then
        print_status "Installing Docker..."
        apt update
        apt install -y docker.io docker-compose
        systemctl start docker
        systemctl enable docker
        print_status "Docker installed successfully"
    else
        print_status "Docker is already installed"
    fi
}

# Function to install Nginx if not present
install_nginx() {
    if ! command -v nginx &> /dev/null; then
        print_status "Installing Nginx..."
        apt install -y nginx
        systemctl start nginx
        systemctl enable nginx
        print_status "Nginx installed successfully"
    else
        print_status "Nginx is already installed"
    fi
}

# Install required packages
print_status "Checking and installing required packages..."
install_docker
install_nginx

# Verify installations
print_status "Verifying installations..."
docker --version
docker-compose --version
nginx -v

# Create summerfest user if it doesn't exist
if ! id "summerfest" &>/dev/null; then
    print_status "Creating summerfest user..."
    adduser --disabled-password --gecos "" summerfest
    usermod -aG docker summerfest
fi

# Set up application directory
APP_DIR="/home/summerfest/stjohns-events"
print_status "Setting up application directory..."
mkdir -p $APP_DIR
chown -R summerfest:summerfest $APP_DIR

# Create necessary directories
print_status "Creating necessary directories..."
mkdir -p $APP_DIR/backend/data
mkdir -p /home/summerfest/backups
chown -R summerfest:summerfest $APP_DIR/backend/data
chown -R summerfest:summerfest /home/summerfest/backups

# Set up Nginx configuration
print_status "Setting up Nginx configuration..."
cat > /etc/nginx/sites-available/summerfest << EOL
# Frontend
server {
    listen 80;
    server_name ${MAIN_DOMAIN};

    location / {
        proxy_pass http://localhost:3000;  # Frontend container
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
        proxy_pass http://localhost:8000;  # Backend container
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
rm -f /etc/nginx/sites-enabled/default  # Remove default site

# Test Nginx configuration
print_status "Testing Nginx configuration..."
nginx -t

# Create docker-compose.prod.yml
print_status "Creating docker-compose.prod.yml..."
cat > $APP_DIR/docker-compose.prod.yml << 'EOL'
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
      - "3000:80"  # Frontend container port 80 mapped to host port 3000
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

# Create .env file template with correct domains
print_status "Creating .env file template..."
cat > $APP_DIR/.env.template << EOL
# Eventbrite API Credentials
EVENTBRITE_API_KEY=your_api_key_here
EVENTBRITE_CLIENT_SECRET=your_client_secret_here
EVENTBRITE_PRIVATE_TOKEN=your_private_token_here
EVENTBRITE_PUBLIC_TOKEN=your_public_token_here

# Backend Environment Variables
BACKEND_CORS_ORIGINS=https://${MAIN_DOMAIN}
ENVIRONMENT=production

# Frontend Environment Variables
VITE_API_URL=https://${API_DOMAIN}
NODE_ENV=production
EOL

# Set proper permissions
print_status "Setting proper permissions..."
chown -R summerfest:summerfest $APP_DIR
chmod 755 $APP_DIR

# Create post-deploy script
print_status "Creating post-deploy script..."
cat > $APP_DIR/post-deploy.sh << 'EOL'
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

# Check if running as summerfest user
if [ "$USER" != "summerfest" ]; then
    print_error "Please run as summerfest user"
    exit 1
fi

# Function to check if .env files are configured
check_env_files() {
    local env_files=(
        "/home/summerfest/stjohns-events/.env"
        "/home/summerfest/stjohns-events/backend/.env"
        "/home/summerfest/stjohns-events/frontend/.env"
    )

    for env_file in "${env_files[@]}"; do
        if [ ! -f "$env_file" ]; then
            print_status "Creating $env_file from template..."
            cp "${env_file}.template" "$env_file" 2>/dev/null || true
        fi
    done

    print_status "Please ensure all .env files are properly configured with your credentials:"
    echo "1. /home/summerfest/stjohns-events/.env"
    echo "2. /home/summerfest/stjohns-events/backend/.env"
    echo "3. /home/summerfest/stjohns-events/frontend/.env"
    echo
    echo "Required credentials:"
    echo "- EVENTBRITE_API_KEY"
    echo "- EVENTBRITE_CLIENT_SECRET"
    echo "- EVENTBRITE_PRIVATE_TOKEN"
    echo "- EVENTBRITE_PUBLIC_TOKEN"
    echo "- EVENTBRITE_OAUTH_TOKEN"
    echo "- EVENTBRITE_ORG_ID"
    echo
    read -p "Press Enter after you have updated the .env files..."
}

# Main deployment process
main() {
    cd /home/summerfest/stjohns-events

    # Check and setup environment files
    check_env_files

    # Stop any running containers
    print_status "Stopping any running containers..."
    docker-compose -f docker-compose.prod.yml down || true

    # Start Nginx
    print_status "Starting Nginx..."
    sudo systemctl start nginx

    # Start the application
    print_status "Starting the application..."
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

main
EOL

# Make scripts executable
chmod +x $APP_DIR/post-deploy.sh

print_status "Initial setup complete!"
echo
echo "Domain configuration:"
echo "Main domain: ${MAIN_DOMAIN}"
echo "API domain: ${API_DOMAIN}"
echo
echo "Next steps:"
echo "1. Ensure your DNS records are configured to point to this server:"
echo "   - ${MAIN_DOMAIN} -> Your server IP"
echo "   - ${API_DOMAIN} -> Your server IP"
echo "2. Switch to summerfest user: su - summerfest"
echo "3. Clone your repository: git clone <your-repo-url> /home/summerfest/stjohns-events"
echo "4. Run the post-deploy script: ./post-deploy.sh"
echo
echo "The post-deploy script will:"
echo "- Check and setup environment files"
echo "- Stop any running containers"
echo "- Start Nginx"
echo "- Start the application"
echo "- Verify the services are running" 