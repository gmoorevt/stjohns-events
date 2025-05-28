# Simplified Deployment Guide for Summerfest Dashboard

This guide provides a streamlined process for deploying the Summerfest Dashboard to a production server.

## Prerequisites

1. A fresh Ubuntu 22.04 LTS server
2. Root access to the server
3. Your domain name and DNS access
4. Your Eventbrite API credentials

## Deployment Steps

### 1. Initial Server Setup

1. SSH into your server as root:
   ```bash
   ssh root@your-server-ip
   ```

2. Update the system and install required packages:
   ```bash
   apt update && apt upgrade -y
   apt install -y docker.io docker-compose nginx
   ```

3. Download the deployment script:
   ```bash
   curl -O https://raw.githubusercontent.com/your-username/stjohns-events/main/deploy.sh
   chmod +x deploy.sh
   ```

4. Run the deployment script:
   ```bash
   ./deploy.sh
   ```

   This script will:
   - Create the `summerfest` user
   - Set up the application directory
   - Configure Nginx for both frontend and backend
   - Create necessary configuration files including the frontend Nginx proxy configuration
   - Set up proper permissions

### 2. Configure Domain and Environment

1. Edit the Nginx configuration:
   ```bash
   nano /etc/nginx/sites-available/summerfest
   ```
   Replace `your-domain.com` with your actual domain name.

2. Switch to the summerfest user:
   ```bash
   su - summerfest
   ```

3. Clone the repository:
   ```bash
   git clone https://github.com/your-username/stjohns-events.git /home/summerfest/stjohns-events
   ```

4. Configure environment variables:
   ```bash
   cd /home/summerfest/stjohns-events
   cp .env.template .env
   cp .env.template backend/.env
   cp .env.template frontend/.env
   ```

   Edit each `.env` file with your actual credentials:
   - `EVENTBRITE_API_KEY`
   - `EVENTBRITE_CLIENT_SECRET`
   - `EVENTBRITE_PRIVATE_TOKEN`
   - `EVENTBRITE_PUBLIC_TOKEN`
   - `EVENTBRITE_OAUTH_TOKEN`
   - `EVENTBRITE_ORG_ID`

   Note: The frontend container is configured to use `/api` as the API URL base path, which is automatically proxied to the backend service.

### 3. Deploy the Application

1. Run the post-deploy script:
   ```bash
   ./post-deploy.sh
   ```

   This script will:
   - Verify environment files
   - Stop any running containers
   - Start Nginx
   - Start the application
   - Verify the services are running
   - Test the Nginx configuration in the frontend container
   - Verify the API proxy is working correctly

### 4. Set Up SSL (Optional but Recommended)

1. Install Certbot:
   ```bash
   sudo apt install -y certbot python3-certbot-nginx
   ```

2. Obtain SSL certificates:
   ```bash
   sudo certbot --nginx -d your-domain.com -d api.your-domain.com
   ```

### 5. Verify Deployment

1. Check if services are running:
   ```bash
   docker ps
   ```

2. Check Nginx status:
   ```bash
   sudo systemctl status nginx
   ```

3. Test the application:
   - Visit `https://your-domain.com` in your browser
   - Test the API at `https://your-domain.com/api/health`
   - Verify that the frontend can communicate with the backend through the API proxy

## Architecture Overview

The application is deployed using Docker containers with the following setup:

1. Frontend Container:
   - Serves the React application
   - Uses Nginx to serve static files
   - Includes a proxy configuration to forward `/api/*` requests to the backend
   - Environment variable `VITE_API_URL=/api` ensures consistent API URL usage

2. Backend Container:
   - Runs the FastAPI application
   - Handles API requests forwarded from the frontend
   - Stores data in a persistent volume

3. Nginx Proxy:
   - Routes external requests to the appropriate container
   - Handles SSL termination (when configured)
   - Provides additional security headers

## Troubleshooting

### Common Issues

1. **Nginx won't start**
   - Check configuration: `sudo nginx -t`
   - Check logs: `sudo tail -f /var/log/nginx/error.log`
   - Verify port 80 is not in use: `sudo lsof -i :80`

2. **Docker containers won't start**
   - Check logs: `docker-compose -f docker-compose.prod.yml logs`
   - Verify environment variables: `cat .env`
   - Check disk space: `df -h`

3. **Application not accessible**
   - Verify DNS settings
   - Check firewall: `sudo ufw status`
   - Test direct IP access
   - Check Cloudflare settings (if using)

4. **API requests failing**
   - Verify frontend Nginx configuration: `docker exec summerfest-frontend cat /etc/nginx/conf.d/default.conf`
   - Check if backend is accessible: `docker exec summerfest-frontend curl http://backend:8000/api/health`
   - Verify network connectivity: `docker network inspect stjohns-events_app-network`

### Useful Commands

```bash
# View application logs
docker-compose -f docker-compose.prod.yml logs -f

# Restart the application
docker-compose -f docker-compose.prod.yml down -v
docker-compose -f docker-compose.prod.yml up -d --build

# Restart Nginx
sudo systemctl restart nginx

# Check container status
docker ps

# View Nginx configuration
sudo nginx -T

# Test API proxy
curl http://localhost:3000/api/health
```

## Maintenance

### Updating the Application

1. Pull the latest changes:
   ```bash
   cd /home/summerfest/stjohns-events
   git pull
   ```

2. Rebuild and restart:
   ```bash
   docker-compose -f docker-compose.prod.yml down -v
   docker-compose -f docker-compose.prod.yml up -d --build
   ```

### Backing Up

1. The application automatically backs up the database daily to `/home/summerfest/backups`
2. Manual backup:
   ```bash
   docker-compose -f docker-compose.prod.yml exec backend sqlite3 /app/data/summerfest.db ".backup '/home/summerfest/backups/manual-backup.db'"
   ```

## Security Notes

1. Keep your system updated:
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. Configure firewall:
   ```bash
   sudo ufw allow ssh
   sudo ufw allow http
   sudo ufw allow https
   sudo ufw enable
   ```

3. Regularly check logs for suspicious activity
4. Keep your Eventbrite API credentials secure
5. Regularly rotate API credentials
6. Monitor system resources and logs
7. Ensure Nginx security headers are properly configured
8. Keep Docker and containers updated