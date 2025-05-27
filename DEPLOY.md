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
   - Configure Nginx
   - Create necessary configuration files
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
   - Test the API at `https://api.your-domain.com/api/health`

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

### Useful Commands

```bash
# View application logs
docker-compose -f docker-compose.prod.yml logs -f

# Restart the application
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml up -d

# Restart Nginx
sudo systemctl restart nginx

# Check container status
docker ps

# View Nginx configuration
sudo nginx -T
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
   docker-compose -f docker-compose.prod.yml down
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