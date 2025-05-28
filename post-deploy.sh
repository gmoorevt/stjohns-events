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

# Function to verify Nginx configuration
verify_nginx_config() {
    print_status "Verifying Nginx configuration in frontend container..."
    
    # Check if the container is running
    if ! docker ps | grep -q "summerfest-frontend"; then
        print_error "Frontend container is not running"
        return 1
    fi

    # Check if the Nginx configuration is correct
    if ! docker exec summerfest-frontend nginx -t; then
        print_error "Nginx configuration in frontend container is invalid"
        return 1
    fi

    # Verify API proxy configuration
    if ! docker exec summerfest-frontend grep -q "location /api/" /etc/nginx/conf.d/default.conf; then
        print_error "API proxy configuration is missing in frontend container"
        return 1
    fi

    print_status "Nginx configuration is valid"
    return 0
}

# Main deployment process
main() {
    cd /home/summerfest/stjohns-events

    # Check and setup environment files
    check_env_files

    # Stop any running containers
    print_status "Stopping any running containers..."
    docker-compose -f docker-compose.prod.yml down -v || true

    # Start Nginx
    print_status "Starting Nginx..."
    sudo systemctl start nginx

    # Start the application
    print_status "Starting the application..."
    docker-compose -f docker-compose.prod.yml up -d --build

    # Wait for containers to start
    print_status "Waiting for containers to start..."
    sleep 5

    # Verify services are running
    print_status "Verifying services..."
    if ! docker ps | grep -q "summerfest-frontend" || ! docker ps | grep -q "summerfest-backend"; then
        print_error "Deployment may have issues. Please check the logs:"
        echo "docker-compose -f docker-compose.prod.yml logs"
        exit 1
    fi

    # Verify Nginx configuration
    if ! verify_nginx_config; then
        print_error "Nginx configuration verification failed"
        exit 1
    fi

    # Test API proxy
    print_status "Testing API proxy..."
    if ! curl -s http://localhost:3000/api/health | grep -q "healthy"; then
        print_error "API proxy test failed"
        exit 1
    fi

    print_status "Deployment successful! All services are running and configured correctly."
}

main 