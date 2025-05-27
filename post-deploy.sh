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

# Function to check if running as summerfest user
check_user() {
    if [ "$USER" != "summerfest" ]; then
        print_error "This script must be run as the summerfest user"
        exit 1
    fi
}

# Function to check if git and docker are installed
check_prerequisites() {
    if ! command -v git >/dev/null 2>&1; then
        print_error "Git is not installed"
    fi
    
    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker is not installed"
    fi
    
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker daemon is not running"
    fi
}

# Function to clone repository
clone_repository() {
    print_status "Cloning repository..."
    
    # Create the directory if it doesn't exist
    if [ ! -d "/home/summerfest/stjohns-events" ]; then
        print_status "Creating application directory..."
        mkdir -p /home/summerfest/stjohns-events
    fi
    
    # Ensure we're in the correct directory
    cd /home/summerfest/stjohns-events
    
    # Check if we have a GitHub token
    if [ -z "$GITHUB_TOKEN" ]; then
        print_status "GitHub token not found. Please set up GitHub authentication:"
        echo "1. Go to GitHub.com -> Settings -> Developer Settings -> Personal Access Tokens -> Tokens (classic)"
        echo "2. Generate a new token with 'repo' access"
        echo "3. Set the token as an environment variable:"
        echo "   export GITHUB_TOKEN=your_token_here"
        echo "4. Run this script again"
        exit 1
    fi
    
    # Remove any existing files (except .env if it exists)
    if [ -d .git ]; then
        print_status "Repository already exists, pulling latest changes..."
        git pull
    else
        # Remove everything except .env files if they exist
        if [ -f .env ]; then
            mv .env .env.backup
        fi
        rm -rf *
        if [ -f .env.backup ]; then
            mv .env.backup .env
        fi
        
        # Clone the repository using the token
        print_status "Cloning repository using GitHub token..."
        git clone https://${GITHUB_TOKEN}@github.com/gmoorevt/stjohns-events.git .
        if [ $? -ne 0 ]; then
            print_error "Failed to clone repository. Please check your GitHub token and repository URL."
            echo "Repository URL: https://github.com/gmoorevt/stjohns-events.git"
            echo "Make sure your token has access to this repository."
        fi
    fi
}

# Function to set up environment variables
setup_environment() {
    print_status "Setting up environment variables..."
    
    # Create root .env if it doesn't exist
    if [ ! -f .env ]; then
        cat > .env << EOL
EVENTBRITE_API_KEY=${EVENTBRITE_API_KEY:-your_api_key}
EVENTBRITE_OAUTH_TOKEN=${EVENTBRITE_OAUTH_TOKEN:-your_oauth_token}
EVENTBRITE_CLIENT_SECRET=${EVENTBRITE_CLIENT_SECRET:-your_client_secret}
EVENTBRITE_PUBLIC_TOKEN=${EVENTBRITE_PUBLIC_TOKEN:-your_public_token}
EVENTBRITE_PRIVATE_TOKEN=${EVENTBRITE_PRIVATE_TOKEN:-your_private_token}
EOL
        print_status "Created root .env file"
    fi
    
    # Create backend .env if it doesn't exist
    if [ ! -f backend/.env ]; then
        cat > backend/.env << EOL
ENVIRONMENT=production
EVENTBRITE_API_KEY=${EVENTBRITE_API_KEY:-your_api_key}
EVENTBRITE_OAUTH_TOKEN=${EVENTBRITE_OAUTH_TOKEN:-your_oauth_token}
EVENTBRITE_CLIENT_SECRET=${EVENTBRITE_CLIENT_SECRET:-your_client_secret}
EVENTBRITE_PUBLIC_TOKEN=${EVENTBRITE_PUBLIC_TOKEN:-your_public_token}
EVENTBRITE_PRIVATE_TOKEN=${EVENTBRITE_PRIVATE_TOKEN:-your_private_token}
EVENTBRITE_ORG_ID=${EVENTBRITE_ORG_ID:-your_org_id}
BACKEND_CORS_ORIGINS=https://your-domain.com
EOL
        print_status "Created backend .env file"
    fi
    
    # Create frontend .env if it doesn't exist
    if [ ! -f frontend/.env ]; then
        cat > frontend/.env << EOL
VITE_API_URL=https://api.your-domain.com
NODE_ENV=production
EOL
        print_status "Created frontend .env file"
    fi
    
    print_status "Please update the following files with your actual credentials:"
    echo "1. /home/summerfest/stjohns-events/.env"
    echo "2. /home/summerfest/stjohns-events/backend/.env"
    echo "3. /home/summerfest/stjohns-events/frontend/.env"
    echo ""
    echo "Required credentials:"
    echo "- EVENTBRITE_API_KEY"
    echo "- EVENTBRITE_OAUTH_TOKEN"
    echo "- EVENTBRITE_CLIENT_SECRET"
    echo "- EVENTBRITE_PUBLIC_TOKEN"
    echo "- EVENTBRITE_PRIVATE_TOKEN"
    echo "- EVENTBRITE_ORG_ID"
    echo "- BACKEND_CORS_ORIGINS (your domain)"
    echo "- VITE_API_URL (your API domain)"
    echo ""
    read -p "Press Enter when you have updated the .env files..."
}

# Function to confirm before testing credentials
confirm_before_test() {
    print_status "Ready to test Eventbrite credentials..."
    echo "This will verify your Eventbrite API access using the credentials in your .env files."
    read -p "Are you ready to proceed? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Credential test cancelled by user"
    fi
}

# Function to install Python dependencies
install_dependencies() {
    print_status "Installing Python dependencies..."
    
    # Check if Python3 is installed
    if ! command -v python3 >/dev/null 2>&1; then
        print_error "Python3 is not installed. Please install Python3 first."
    fi
    
    # Check if pip is installed
    if ! command -v pip3 >/dev/null 2>&1; then
        print_error "pip3 is not installed. Please run as root: sudo apt-get install python3-pip python3-venv"
    fi
    
    cd /home/summerfest/stjohns-events/backend
    
    # Create and activate virtual environment
    print_status "Setting up Python virtual environment..."
    python3 -m venv venv
    source venv/bin/activate
    
    # Upgrade pip
    pip install --upgrade pip
    
    # Install dependencies from requirements.txt
    print_status "Installing requirements from requirements.txt..."
    pip install -r requirements.txt
    if [ $? -ne 0 ]; then
        print_error "Failed to install Python dependencies"
    fi
    
    # Deactivate virtual environment
    deactivate
    
    cd ..
}

# Function to test credentials
test_credentials() {
    print_status "Testing Eventbrite credentials..."
    cd backend
    
    # Activate virtual environment
    source venv/bin/activate
    
    if ! python test_credentials.py; then
        # Deactivate virtual environment before exiting
        deactivate
        print_error "Eventbrite credentials test failed. Please check your credentials in the .env files."
    fi
    
    # Deactivate virtual environment
    deactivate
    cd ..
}

# Function to start the application
start_application() {
    print_status "Starting the application..."
    
    # Build and start the containers
    print_status "Building and starting Docker containers..."
    docker-compose -f docker-compose.prod.yml up -d --build
    
    # Wait for services to start
    print_status "Waiting for services to start..."
    sleep 10
    
    # Verify services are running
    print_status "Verifying services..."
    if ! docker-compose -f docker-compose.prod.yml ps | grep -q "Up"; then
        print_error "Some services failed to start. Check the logs with: docker-compose -f docker-compose.prod.yml logs"
    fi
}

# Function to verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    # Check if backend is responding
    print_status "Checking backend service..."
    if ! curl -s http://localhost:8000/api/health > /dev/null; then
        print_error "Backend service is not responding"
    fi
    
    # Check if frontend is accessible
    print_status "Checking frontend service..."
    if ! curl -s http://localhost:80 > /dev/null; then
        print_error "Frontend service is not accessible"
    fi
    
    print_status "Deployment verification complete!"
}

# Function to verify Nginx configuration
verify_nginx_config() {
    print_status "Verifying Nginx configuration..."
    
    # Check if Nginx is installed
    if ! command -v nginx &> /dev/null; then
        print_error "Nginx is not installed"
        exit 1
    fi

    # Check if our configuration exists
    if [ ! -f /etc/nginx/sites-available/summerfest ]; then
        print_error "Nginx configuration not found"
        exit 1
    fi

    # Verify the frontend proxy_pass is set to port 3000
    if ! grep -q "proxy_pass http://localhost:3000" /etc/nginx/sites-available/summerfest; then
        print_error "Nginx configuration has incorrect frontend proxy_pass port"
        echo "Please ensure the frontend proxy_pass is set to port 3000"
        exit 1
    fi

    # Test Nginx configuration
    if ! sudo nginx -t; then
        print_error "Nginx configuration test failed"
        exit 1
    fi

    print_status "Nginx configuration verified successfully"
}

# Function to verify Docker setup
verify_docker_setup() {
    print_status "Verifying Docker setup..."
    
    # Check if Docker is installed and running
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi

    if ! docker info &> /dev/null; then
        print_error "Docker is not running"
        exit 1
    fi

    # Check if user is in docker group
    if ! groups | grep -q docker; then
        print_error "User is not in docker group"
        echo "Please run: sudo usermod -aG docker summerfest"
        exit 1
    fi

    print_status "Docker setup verified successfully"
}

# Function to verify port availability
verify_ports() {
    print_status "Verifying port availability..."
    
    # Check if port 3000 is available
    if netstat -tuln | grep -q ":3000 "; then
        print_error "Port 3000 is already in use"
        echo "Please ensure no other service is using port 3000"
        exit 1
    fi

    # Check if port 8000 is available
    if netstat -tuln | grep -q ":8000 "; then
        print_error "Port 8000 is already in use"
        echo "Please ensure no other service is using port 8000"
        exit 1
    fi

    print_status "Ports verified successfully"
}

# Main deployment function
deploy() {
    print_status "Starting post-deployment setup..."
    
    # Check prerequisites
    check_user
    check_prerequisites
    
    # Clone repository first
    clone_repository
    
    # Then set up environment
    setup_environment
    
    # Install Python dependencies
    install_dependencies
    
    # Confirm before testing credentials
    confirm_before_test
    
    # Test credentials
    test_credentials
    
    # Start the application
    start_application
    
    # Verify deployment
    verify_deployment
    
    # Verify Nginx configuration
    verify_nginx_config

    # Verify Docker setup
    verify_docker_setup

    # Verify ports
    verify_ports
    
    print_status "Post-deployment setup complete!"
    print_status "Next steps:"
    echo "1. Update your DNS records in Cloudflare"
    echo "2. Verify SSL/TLS settings in Cloudflare"
    echo "3. Monitor the application logs: docker-compose -f docker-compose.prod.yml logs -f"
    echo "4. Test the application by visiting your domain"
}

# Run the deployment
deploy 