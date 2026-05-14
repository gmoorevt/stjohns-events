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

    # Ensure the Cloudflare Origin Certificate directory exists.
    # The cert/key must be placed at /etc/ssl/cloudflare/{origin.pem,origin.key}
    # before nginx will start successfully on 443.
    mkdir -p /etc/ssl/cloudflare
    chmod 700 /etc/ssl/cloudflare

    local HAS_ORIGIN_CERT=0
    if [ -f /etc/ssl/cloudflare/origin.pem ] && [ -f /etc/ssl/cloudflare/origin.key ]; then
        HAS_ORIGIN_CERT=1
        chmod 600 /etc/ssl/cloudflare/origin.key
    else
        print_status "Cloudflare Origin Certificate not found at /etc/ssl/cloudflare/origin.{pem,key}."
        print_status "HTTPS server blocks will be omitted; only HTTP will be served until you install the cert."
        print_status "Generate one in the Cloudflare dashboard (SSL/TLS -> Origin Server -> Create Certificate),"
        print_status "then re-run this script (or write the files and 'nginx -s reload')."
    fi

    # Write the Nginx site config.
    {
        cat <<EOL
# Direct IP access (debugging / health checks) -- HTTP only, no cert.
server {
    listen 80 default_server;
    server_name _;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}

# Redirect plain HTTP to HTTPS for both hostnames.
server {
    listen 80;
    server_name ${MAIN_DOMAIN} ${API_DOMAIN};
    return 301 https://\$host\$request_uri;
}
EOL

        if [ "$HAS_ORIGIN_CERT" = "1" ]; then
            cat <<EOL

# Frontend (HTTPS)
server {
    listen 443 ssl http2;
    server_name ${MAIN_DOMAIN};

    ssl_certificate     /etc/ssl/cloudflare/origin.pem;
    ssl_certificate_key /etc/ssl/cloudflare/origin.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}

# Backend API (HTTPS)
server {
    listen 443 ssl http2;
    server_name ${API_DOMAIN};

    ssl_certificate     /etc/ssl/cloudflare/origin.pem;
    ssl_certificate_key /etc/ssl/cloudflare/origin.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    location / {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOL
        fi
    } > /etc/nginx/sites-available/summerfest

    # Enable the site
    ln -sf /etc/nginx/sites-available/summerfest /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default

    # Open port 443 in the firewall if ufw is active.
    if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
        ufw allow https || true
    fi

    # Test Nginx configuration
    print_status "Testing Nginx configuration..."
    nginx -t

    # Start Nginx
    systemctl start nginx
    systemctl enable nginx
    systemctl reload nginx || true
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
      - EVENTBRITE_OAUTH_TOKEN=${EVENTBRITE_OAUTH_TOKEN}
      - EVENTBRITE_ORG_ID=${EVENTBRITE_ORG_ID}
      - EVENTBRITE_EVENT_ID=${EVENTBRITE_EVENT_ID}
      - DATABASE_URL=sqlite:////app/data/summerfest.db
      - ADMIN_EMAIL=${ADMIN_EMAIL}
      - JWT_SECRET=${JWT_SECRET}
      - JWT_TTL_DAYS=30
      - COOKIE_SECURE=true
      - POSTMARK_SERVER_TOKEN=${POSTMARK_SERVER_TOKEN}
      - POSTMARK_FROM_EMAIL=${POSTMARK_FROM_EMAIL}
      - POSTMARK_MESSAGE_STREAM=${POSTMARK_MESSAGE_STREAM:-outbound}
      - APP_BASE_URL=${APP_BASE_URL}
      - BACKEND_CORS_ORIGINS=${BACKEND_CORS_ORIGINS}
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
    environment:
      - VITE_API_URL=${VITE_API_URL}
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
EVENTBRITE_EVENT_ID=1989097915410

# Auth
ADMIN_EMAIL=geody.moore@gmail.com
# Generate with: python -c "import secrets; print(secrets.token_urlsafe(48))"
JWT_SECRET=replace_with_random_48_byte_secret

# Postmark (HTTPS API — required because DigitalOcean blocks outbound SMTP).
# Get the Server Token from https://account.postmarkapp.com/servers — under your
# server, "API Tokens" tab. POSTMARK_FROM_EMAIL must be a verified Sender
# Signature (or a verified domain) in Postmark.
POSTMARK_SERVER_TOKEN=your_postmark_server_token_here
POSTMARK_FROM_EMAIL=no-reply@stjohns-hingham-events.org
POSTMARK_MESSAGE_STREAM=outbound

# App URLs / CORS
APP_BASE_URL=https://${MAIN_DOMAIN}
BACKEND_CORS_ORIGINS=https://${MAIN_DOMAIN}
ENVIRONMENT=production

# Frontend
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
    echo "1. Configure DNS records to point to this server (206.189.192.35):"
    echo "   - ${MAIN_DOMAIN} -> 206.189.192.35"
    echo "   - ${API_DOMAIN} -> 206.189.192.35"
    echo "2. Generate a Gmail App Password at https://myaccount.google.com/apppasswords"
    echo "   (requires 2-Step Verification on the Google account)"
    echo "3. Generate a JWT secret:"
    echo "   python3 -c 'import secrets; print(secrets.token_urlsafe(48))'"
    echo "4. Fill in /home/summerfest/stjohns-events/.env from the template, including:"
    echo "   - ADMIN_EMAIL, JWT_SECRET, POSTMARK_SERVER_TOKEN, POSTMARK_FROM_EMAIL, APP_BASE_URL"
    echo "5. Install a Cloudflare Origin Certificate (required for COOKIE_SECURE=true"
    echo "   and Cloudflare SSL mode 'Full (strict)'):"
    echo "   a. In the Cloudflare dashboard for stjohns-hingham-events.org:"
    echo "        SSL/TLS -> Origin Server -> Create Certificate"
    echo "      Include hostnames: ${MAIN_DOMAIN}, *.${MAIN_DOMAIN} (or ${API_DOMAIN})."
    echo "      Pick RSA, 15 years, format PEM."
    echo "   b. On this server, paste the certificate and private key to:"
    echo "        /etc/ssl/cloudflare/origin.pem"
    echo "        /etc/ssl/cloudflare/origin.key   (chmod 600)"
    echo "   c. Re-run setup_nginx (or 'sudo bash $0' to refresh the config),"
    echo "      then 'sudo nginx -t && sudo systemctl reload nginx'."
    echo "   d. In Cloudflare, set SSL/TLS -> Overview -> Encryption mode to 'Full (strict)'."
    echo "6. Restart the app: docker-compose -f docker-compose.prod.yml up -d --build"
    echo "7. First sign-in: visit https://${MAIN_DOMAIN}/login, request a magic link"
    echo "   to ADMIN_EMAIL, then set a password from the Account page."
    echo
    echo "To check the application status:"
    echo "docker ps"
    echo "docker-compose -f /home/summerfest/stjohns-events/docker-compose.prod.yml logs"
}

# Run the deployment
main 