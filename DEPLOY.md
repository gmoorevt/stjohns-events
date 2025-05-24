# Deploying Summerfest Dashboard to Digital Ocean

This guide provides step-by-step instructions for deploying the Summerfest Dashboard to Digital Ocean using Docker.

## Prerequisites

1. A Digital Ocean account
2. The `doctl` CLI tool installed
3. Docker and Docker Compose installed locally
4. Your Eventbrite API credentials

## Deployment Steps

### 1. Create a Digital Ocean Droplet

1. Log in to your Digital Ocean account
2. Create a new Droplet:
   - Choose Ubuntu 22.04 LTS
   - Select a Basic plan (2GB RAM / 1 CPU minimum recommended)
   - Choose a datacenter region close to your users
   - Add your SSH key
   - Name it `summerfest-dashboard`

### 2. Set Up the Server

1. SSH into your droplet:
   ```bash
   ssh root@your-droplet-ip
   ```

2. Update the system and install Docker:
   ```bash
   apt update && apt upgrade -y
   apt install -y docker.io docker-compose
   ```

3. Create a non-root user (recommended):
   ```bash
   adduser summerfest
   usermod -aG docker summerfest
   ```

4. Switch to the new user:
   ```bash
   su - summerfest
   ```

### 3. Deploy the Application

1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/summerfest.git
   cd summerfest
   ```

2. Create the production environment files:

   Backend `.env`:
   ```bash
   # Create backend .env
   cat > backend/.env << EOL
   ENVIRONMENT=production
   EVENTBRITE_API_KEY=your_api_key
   EVENTBRITE_OAUTH_TOKEN=your_oauth_token
   EVENTBRITE_ORG_ID=your_org_id
   BACKEND_CORS_ORIGINS=https://your-domain.com
   EOL
   ```

   Frontend `.env`:
   ```bash
   # Create frontend .env
   cat > frontend/.env << EOL
   VITE_API_URL=https://api.your-domain.com
   NODE_ENV=production
   EOL
   ```

3. Build and start the containers:
   ```bash
   docker compose -f docker-compose.prod.yml up -d --build
   ```

### 4. Set Up Nginx as a Reverse Proxy

1. Install Nginx:
   ```bash
   sudo apt install -y nginx
   ```

2. Create Nginx configuration:
   ```bash
   sudo nano /etc/nginx/sites-available/summerfest
   ```

3. Add the following configuration:
   ```nginx
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
   ```

4. Enable the site and restart Nginx:
   ```bash
   sudo ln -s /etc/nginx/sites-available/summerfest /etc/nginx/sites-enabled/
   sudo nginx -t
   sudo systemctl restart nginx
   ```

### 5. Set Up SSL with Certbot

1. Install Certbot:
   ```bash
   sudo apt install -y certbot python3-certbot-nginx
   ```

2. Obtain SSL certificates:
   ```bash
   sudo certbot --nginx -d your-domain.com -d api.your-domain.com
   ```

### 6. Monitoring and Maintenance

1. View logs:
   ```bash
   # All containers
   docker compose -f docker-compose.prod.yml logs -f

   # Specific service
   docker compose -f docker-compose.prod.yml logs -f backend
   docker compose -f docker-compose.prod.yml logs -f frontend
   ```

2. Update the application:
   ```bash
   git pull
   docker compose -f docker-compose.prod.yml down
   docker compose -f docker-compose.prod.yml up -d --build
   ```

3. Backup the database:
   ```bash
   # Create a backup script
   cat > backup.sh << EOL
   #!/bin/bash
   BACKUP_DIR="/home/summerfest/backups"
   mkdir -p $BACKUP_DIR
   docker compose -f docker-compose.prod.yml exec backend sqlite3 /app/data/summerfest.db ".backup '$BACKUP_DIR/summerfest-\$(date +%Y%m%d).db'"
   EOL

   chmod +x backup.sh
   ```

4. Set up automatic backups (optional):
   ```bash
   # Add to crontab
   (crontab -l 2>/dev/null; echo "0 2 * * * /home/summerfest/backup.sh") | crontab -
   ```

## Troubleshooting

### Common Issues

1. **Application not accessible**
   - Check if containers are running: `docker ps`
   - Check container logs: `docker compose -f docker-compose.prod.yml logs`
   - Verify Nginx configuration: `sudo nginx -t`
   - Check firewall settings: `sudo ufw status`

2. **Database issues**
   - Verify database volume: `docker volume ls`
   - Check database file permissions
   - Restore from backup if needed

3. **API connection issues**
   - Verify environment variables
   - Check CORS settings
   - Test API endpoint directly: `curl https://api.your-domain.com/api/metrics`

### Security Considerations

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

3. Regular maintenance:
   - Monitor disk space: `df -h`
   - Check system logs: `journalctl -xe`
   - Review container logs regularly
   - Keep backups up to date

## Support

If you encounter any issues during deployment, please:
1. Check the logs for error messages
2. Verify all environment variables are set correctly
3. Ensure all ports are properly configured
4. Contact the development team with specific error messages and logs 