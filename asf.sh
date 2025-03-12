#!/bin/bash
# Enhanced Archi Steam Farm Docker Installation Script
# Offers choice between Nginx and Apache2
# Uses .env file for configuration

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}     Archi Steam Farm Docker Installation Script   ${NC}"
echo -e "${GREEN}==================================================${NC}"

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${YELLOW}Please run as root or with sudo privileges${NC}"
  exit 1
fi

# Function to generate a random password
generate_password() {
  tr -dc A-Za-z0-9\!\@\#\$\%\^\&\*\(\)-+= < /dev/urandom | head -c 32
}

# Function to generate a random crypto key
generate_crypto_key() {
  openssl rand -base64 32
}

# Function to create or update .env file
setup_env_file() {
  ENV_FILE="/opt/asf/.env"
  
  # Check if .env file exists
  if [ -f "$ENV_FILE" ]; then
    echo -e "${YELLOW}Existing .env file found. Using its values.${NC}"
  else
    echo -e "${GREEN}Creating new .env file with default values...${NC}"
    
    # Generate default values
    IPC_PASSWORD=$(generate_password)
    CRYPT_KEY=$(generate_crypto_key)
    
    # Create .env file
    cat > "$ENV_FILE" << EOL
# ASF Environment Configuration

# Domain Settings
MAIN_DOMAIN=example.com
ASF_SUBDOMAIN=asf

# Security
ASF_IPC_PASSWORD=${IPC_PASSWORD}
ASF_CRYPT_KEY=${CRYPT_KEY}

# Web Server (apache2 or nginx)
WEB_SERVER=apache2

# Docker Settings
ASF_RESTART_POLICY=unless-stopped
ASF_PORT=1242

# Time Zone
TZ=Europe/Berlin
EOL
    
    echo -e "${GREEN}Default .env file created at ${ENV_FILE}${NC}"
    echo -e "${YELLOW}Please edit this file to customize your settings.${NC}"
    echo -e "${YELLOW}Then run this script again to apply the settings.${NC}"
    
    # Set permissions for .env file
    chmod 600 "$ENV_FILE"
    
    # Open editor for user to modify values
    echo -e "${GREEN}Opening .env file for editing...${NC}"
    echo -e "${YELLOW}Press any key to continue...${NC}"
    read -n 1 -s
    
    if command -v nano &> /dev/null; then
      nano "$ENV_FILE"
    elif command -v vim &> /dev/null; then
      vim "$ENV_FILE"
    elif command -v vi &> /dev/null; then
      vi "$ENV_FILE"
    else
      echo -e "${RED}No text editor found. Please edit ${ENV_FILE} manually.${NC}"
    fi
  fi
  
  # Source the .env file to get its values
  source "$ENV_FILE"
  
  # Validate required values
  if [ -z "$MAIN_DOMAIN" ] || [ "$MAIN_DOMAIN" = "example.com" ]; then
    echo -e "${RED}MAIN_DOMAIN is not set or still has default value.${NC}"
    echo -e "${YELLOW}Please edit ${ENV_FILE} and set a valid domain.${NC}"
    exit 1
  fi
  
  if [ -z "$ASF_SUBDOMAIN" ]; then
    echo -e "${RED}ASF_SUBDOMAIN is not set.${NC}"
    echo -e "${YELLOW}Please edit ${ENV_FILE} and set a valid subdomain.${NC}"
    exit 1
  fi
  
  # Set full domain
  DOMAIN="${ASF_SUBDOMAIN}.${MAIN_DOMAIN}"
  
  echo -e "${GREEN}Configuration loaded from .env file.${NC}"
  echo -e "${GREEN}ASF will be installed at: https://${DOMAIN}${NC}"
}

# Function to check and install Docker
install_docker() {
  if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker is not installed. Installing Docker...${NC}"
    
    # Install prerequisites
    apt update
    apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release
    
    # Add Docker's official GPG key
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Set up the stable repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Enable and start Docker service
    systemctl enable docker
    systemctl start docker
    
    echo -e "${GREEN}Docker installed successfully!${NC}"
  else
    echo -e "${GREEN}Docker is already installed, continuing...${NC}"
  fi

  # Check if Docker Compose is installed
  if ! docker compose version &> /dev/null; then
    echo -e "${YELLOW}Docker Compose plugin is not installed. Installing...${NC}"
    apt install -y docker-compose-plugin
    echo -e "${GREEN}Docker Compose plugin installed successfully!${NC}"
  else
    echo -e "${GREEN}Docker Compose plugin is already installed, continuing...${NC}"
  fi
}

# Function to check and install web server
install_web_server() {
  APACHE_INSTALLED=false
  NGINX_INSTALLED=false

  # Check if Apache is installed
  if command -v apache2 &> /dev/null; then
    APACHE_INSTALLED=true
    echo -e "${GREEN}Apache2 is installed.${NC}"
  fi

  # Check if Nginx is installed
  if command -v nginx &> /dev/null; then
    NGINX_INSTALLED=true
    echo -e "${GREEN}Nginx is installed.${NC}"
  fi

  # If neither is installed, ask the user which one to install
  if [ "$APACHE_INSTALLED" = false ] && [ "$NGINX_INSTALLED" = false ]; then
    echo -e "${YELLOW}No web server detected. Which web server would you like to install?${NC}"
    echo -e "1) Apache2"
    echo -e "2) Nginx"
    
    while true; do
      read -p "Enter your choice (1 or 2): " WEB_SERVER_CHOICE
      case $WEB_SERVER_CHOICE in
        1)
          WEB_SERVER="apache2"
          echo -e "${GREEN}Installing Apache2...${NC}"
          apt update
          apt install -y apache2
          
          # Enable necessary Apache modules
          a2enmod proxy proxy_http proxy_wstunnel ssl rewrite headers
          
          # Update .env file with choice
          sed -i "s/^WEB_SERVER=.*/WEB_SERVER=apache2/" /opt/asf/.env
          
          break
          ;;
        2)
          WEB_SERVER="nginx"
          echo -e "${GREEN}Installing Nginx...${NC}"
          apt update
          apt install -y nginx
          
          # Update .env file with choice
          sed -i "s/^WEB_SERVER=.*/WEB_SERVER=nginx/" /opt/asf/.env
          
          break
          ;;
        *)
          echo -e "${RED}Invalid choice. Please enter 1 or 2.${NC}"
          ;;
      esac
    done
  else
    # If at least one is installed, check .env preference
    if [ "$WEB_SERVER" = "apache2" ] && [ "$APACHE_INSTALLED" = false ]; then
      echo -e "${YELLOW}.env specifies Apache2 but it's not installed. Installing Apache2...${NC}"
      apt update
      apt install -y apache2
      a2enmod proxy proxy_http proxy_wstunnel ssl rewrite headers
    elif [ "$WEB_SERVER" = "nginx" ] && [ "$NGINX_INSTALLED" = false ]; then
      echo -e "${YELLOW}.env specifies Nginx but it's not installed. Installing Nginx...${NC}"
      apt update
      apt install -y nginx
    elif [ "$WEB_SERVER" != "apache2" ] && [ "$WEB_SERVER" != "nginx" ]; then
      # If .env value is invalid but we have a server installed, use the installed one
      if [ "$APACHE_INSTALLED" = true ]; then
        echo -e "${YELLOW}Invalid web server in .env. Using installed Apache2.${NC}"
        WEB_SERVER="apache2"
        sed -i "s/^WEB_SERVER=.*/WEB_SERVER=apache2/" /opt/asf/.env
      else
        echo -e "${YELLOW}Invalid web server in .env. Using installed Nginx.${NC}"
        WEB_SERVER="nginx"
        sed -i "s/^WEB_SERVER=.*/WEB_SERVER=nginx/" /opt/asf/.env
      fi
    fi
  fi

  echo -e "${GREEN}Using ${WEB_SERVER} as web server.${NC}"
  
  # Enable necessary modules for Apache if it's the chosen server
  if [ "$WEB_SERVER" = "apache2" ]; then
    echo -e "${GREEN}Enabling necessary Apache modules...${NC}"
    a2enmod proxy proxy_http proxy_wstunnel ssl rewrite headers
  fi
}

# Function to setup ASF
setup_asf() {
  # Check if ASF is already installed
  ASF_ALREADY_INSTALLED=false
  if [ -d "/opt/asf" ] && [ -f "/opt/asf/docker-compose.yml" ]; then
    ASF_ALREADY_INSTALLED=true
    echo -e "${YELLOW}ASF installation detected at /opt/asf${NC}"
  fi

  # Create or update ASF structure
  if [ "$ASF_ALREADY_INSTALLED" = true ]; then
    echo -e "${GREEN}Updating existing ASF installation...${NC}"
    # Create backup of existing configs
    BACKUP_DATE=$(date +"%Y%m%d_%H%M%S")
    echo -e "${GREEN}Creating backup of existing ASF configuration to /opt/asf/backup_${BACKUP_DATE}${NC}"
    mkdir -p /opt/asf/backup_${BACKUP_DATE}
    
    # Backup existing configs
    if [ -f "/opt/asf/config/ASF.json" ]; then
      cp /opt/asf/config/ASF.json /opt/asf/backup_${BACKUP_DATE}/
    fi
    if [ -f "/opt/asf/docker-compose.yml" ]; then
      cp /opt/asf/docker-compose.yml /opt/asf/backup_${BACKUP_DATE}/
    fi
    
    # Backup web server config files
    if [ "$WEB_SERVER" = "apache2" ] && [ -f "/etc/apache2/sites-available/asf-${DOMAIN}.conf" ]; then
      cp /etc/apache2/sites-available/asf-${DOMAIN}.conf /opt/asf/backup_${BACKUP_DATE}/
    elif [ "$WEB_SERVER" = "nginx" ] && [ -f "/etc/nginx/sites-available/asf-${DOMAIN}" ]; then
      cp /etc/nginx/sites-available/asf-${DOMAIN} /opt/asf/backup_${BACKUP_DATE}/
    fi
    
    # Preserve existing bot configs by moving them to the backup
    find /opt/asf/config -name "*.json" ! -name "ASF.json" -exec cp {} /opt/asf/backup_${BACKUP_DATE}/ \;
    echo -e "${GREEN}Existing bot configurations have been backed up${NC}"
  else
    echo -e "${GREEN}Installing ASF for the first time...${NC}"
    # Create directory structure for ASF
    mkdir -p /opt/asf/config
    mkdir -p /opt/asf/plugins
  fi

  # Stop services to ensure clean restart
  echo -e "${YELLOW}Stopping services...${NC}"
  if [ "$ASF_ALREADY_INSTALLED" = true ]; then
    cd /opt/asf
    docker compose down
  fi
  
  if [ "$WEB_SERVER" = "apache2" ]; then
    systemctl stop apache2
  elif [ "$WEB_SERVER" = "nginx" ]; then
    systemctl stop nginx
  fi

  # Remove crash file if it exists
  if [ -f "/opt/asf/config/ASF.crash" ]; then
    echo -e "${YELLOW}Removing ASF crash file...${NC}"
    rm -f /opt/asf/config/ASF.crash
  fi

  # Create ASF's main configuration file (ASF.json) - simplified version
  echo -e "${GREEN}Creating/updating ASF configuration file...${NC}"
  cat > /opt/asf/config/ASF.json << EOL
{
  "Headless": false,
  "IPCEnabled": true,
  "IPCSIP": "*",
  "IPCPort": ${ASF_PORT},
  "IPCPassword": "${ASF_IPC_PASSWORD}",
  "SteamProtocols": 7,
  "ConnectionTimeout": 90,
  "MaxFarmingTime": 10,
  "FarmingDelay": 15,
  "AcceptConfirmationsPeriod": 10,
  "IPC": true,
  "WebProxyIPCAuthentication": true,
  "WebProxyIPCPassword": "${ASF_IPC_PASSWORD}",
  "BlockedBots": [],
  "SteamMasterClanID": 0,
  "CurrentCulture": "de-DE"
}
EOL

  # Disable the plugin to avoid issues
  mkdir -p /opt/asf/config/plugins/SteamTokenDumper
  cat > /opt/asf/config/plugins/SteamTokenDumper/ASF.json << EOL
{
  "Enabled": false
}
EOL

  # Create a docker-compose.yml file with host networking
  echo -e "${GREEN}Creating/updating docker-compose.yml file...${NC}"
  cat > /opt/asf/docker-compose.yml << EOL
version: '3'

services:
  asf:
    container_name: asf
    image: justarchi/archisteamfarm:latest
    restart: ${ASF_RESTART_POLICY}
    network_mode: "host"
    volumes:
      - ./config:/app/config
      - ./plugins:/app/plugins
    environment:
      - ASF_CRYPTKEY=${ASF_CRYPT_KEY}
      - TZ=Europe/Berlin
    command: ["--ignore-unsupported-environment"]
EOL

  # Configure web server
  if [ "$WEB_SERVER" = "apache2" ]; then
    configure_apache
  elif [ "$WEB_SERVER" = "nginx" ]; then
    configure_nginx
  fi

  # Restore bot configurations if they were backed up
  if [ "$ASF_ALREADY_INSTALLED" = true ] && [ -d "/opt/asf/backup_${BACKUP_DATE}" ]; then
    echo -e "${GREEN}Restoring bot configurations from backup...${NC}"
    find /opt/asf/backup_${BACKUP_DATE}/ -name "*.json" ! -name "ASF.json" -exec cp {} /opt/asf/config/ \;
  fi

  # Create helper script for Steam Guard authentication
  echo -e "${GREEN}Creating Steam Guard helper scripts...${NC}"
  
  # Auth helper script
  cat > /opt/asf/asf-auth-helper.sh << 'EOL'
#!/bin/bash
# ASF Steam Guard Authentication Helper
# This script helps monitor ASF logs for authentication requests and provides guidance

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}     ASF Steam Guard Authentication Helper        ${NC}"
echo -e "${GREEN}==================================================${NC}"

# Load .env file if it exists
if [ -f "/opt/asf/.env" ]; then
  source "/opt/asf/.env"
  DOMAIN="${ASF_SUBDOMAIN}.${MAIN_DOMAIN}"
else
  echo -e "${RED}Error: .env file not found. Using default domain.${NC}"
  DOMAIN="asf.example.com"
fi

echo -e "${BLUE}This utility will monitor ASF logs for authentication requests${NC}"
echo -e "${BLUE}and provide guidance on how to respond to them.${NC}"
echo -e ""
echo -e "${YELLOW}Keep this window open while you're starting your bots${NC}"
echo -e "${YELLOW}or when you need help with authentication.${NC}"
echo -e ""
echo -e "${GREEN}Starting log monitoring...${NC}"
echo -e "${GREEN}Press Ctrl+C to exit${NC}"
echo -e ""

# Function to watch for authentication requests
watch_for_auth() {
  docker logs --follow asf 2>&1 | grep --line-buffered -E "GetUserInput|SteamGuard|Authenticator|authentication code" | while read -r line; do
    if [[ $line == *"SteamGuard"* || $line == *"authentication code"* || $line == *"GetUserInput"* ]]; then
      echo -e "${RED}======================================================${NC}"
      echo -e "${YELLOW}Authentication Required!${NC}"
      echo -e "${BLUE}${line}${NC}"
      echo -e ""
      
      # Try to extract bot name
      BOT_NAME=$(echo "$line" | grep -oP '(?<=\|)[^|]+(?=\|)' | awk '{print $1}')
      
      echo -e "${GREEN}To provide the code via the web interface:${NC}"
      echo -e "1. Go to ${YELLOW}https://${DOMAIN}${NC}"
      
      if [[ $line == *"SteamGuard"* ]]; then
        echo -e "2. In the command line tab, enter: ${YELLOW}2fa $BOT_NAME <code>${NC}"
      else
        echo -e "2. In the command line tab, enter: ${YELLOW}input $BOT_NAME <code>${NC}"
      fi
      
      echo -e "${RED}======================================================${NC}"
      echo -e ""
    fi
  done
}

# Start monitoring
watch_for_auth
EOL

  # .maFile import helper script
  cat > /opt/asf/asf-import-mafile.sh << 'EOL'
#!/bin/bash
# ASF .maFile Import Helper
# This script helps users import .maFile files from Steam Desktop Authenticator

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${GREEN}==================================================${NC}"
echo -e "${GREEN}     ASF Steam Desktop Authenticator Import       ${NC}"
echo -e "${GREEN}==================================================${NC}"

# Load .env file if it exists
if [ -f "/opt/asf/.env" ]; then
  source "/opt/asf/.env"
  DOMAIN="${ASF_SUBDOMAIN}.${MAIN_DOMAIN}"
else
  echo -e "${RED}Error: .env file not found. Using default domain.${NC}"
  DOMAIN="asf.example.com"
fi

echo -e "${BLUE}This helper will assist you in importing a .maFile from Steam Desktop Authenticator.${NC}"
echo -e ""

# Ask for the .maFile path
echo -e "${YELLOW}Please enter the full path to your .maFile:${NC}"
read -e MA_FILE_PATH

# Check if the file exists
if [ ! -f "$MA_FILE_PATH" ]; then
  echo -e "${RED}Error: File not found at $MA_FILE_PATH${NC}"
  exit 1
fi

# Ask for bot name
echo -e "${YELLOW}Please enter the name for your bot (e.g., MyBot):${NC}"
read BOT_NAME

if [ -z "$BOT_NAME" ]; then
  echo -e "${RED}Error: Bot name cannot be empty${NC}"
  exit 1
fi

# Copy the .maFile to the ASF config directory
echo -e "${GREEN}Copying .maFile to ASF config directory...${NC}"
cp "$MA_FILE_PATH" "/opt/asf/config/$(basename "$MA_FILE_PATH")"
MA_FILE_BASENAME=$(basename "$MA_FILE_PATH")

echo -e "${GREEN}File copied successfully.${NC}"
echo -e ""

# Display instructions for both methods
echo -e "${BLUE}Method 1: Import via Web Interface${NC}"
echo -e "${GREEN}1. Access the ASF web interface at: https://${DOMAIN}${NC}"
echo -e "${GREEN}2. Go to the 'Command' tab${NC}"
echo -e "${GREEN}3. Run the following command:${NC}"
echo -e "${YELLOW}   2fa import $BOT_NAME /app/config/$MA_FILE_BASENAME${NC}"
echo -e "${GREEN}4. ASF will import the authenticator and confirm when done${NC}"
echo -e ""

echo -e "${BLUE}Method 2: Manual Bot Configuration${NC}"
echo -e "${GREEN}1. Extract the .maFile content:${NC}"
MA_CONTENT=$(cat "$MA_FILE_PATH")
echo -e "${YELLOW}   $MA_CONTENT${NC}"
echo -e ""
echo -e "${GREEN}2. Create a bot configuration file at /opt/asf/config/$BOT_NAME.json with:${NC}"

cat << EOLL
{
  "SteamLogin": "your_steam_username",
  "SteamPassword": "your_steam_password",
  "Enabled": true,
  "UseNewerAuthenticatorFormat": true,
  "SteamAuthenticator": $MA_CONTENT
}
EOLL

echo -e ""
echo -e "${GREEN}3. Replace 'your_steam_username' and 'your_steam_password' with your actual credentials${NC}"
echo -e "${GREEN}4. Restart ASF with: ${YELLOW}cd /opt/asf && docker compose down && docker compose up -d${NC}"
echo -e ""

echo -e "${BLUE}Would you like to automatically create this bot configuration file? (y/n)${NC}"
read -n 1 -r CREATE_CONFIG

echo -e ""

if [[ $CREATE_CONFIG =~ ^[Yy]$ ]]; then
  echo -e "${YELLOW}Please enter your Steam username:${NC}"
  read STEAM_USERNAME
  
  echo -e "${YELLOW}Please enter your Steam password:${NC}"
  read -s STEAM_PASSWORD
  echo -e ""
  
  if [ -z "$STEAM_USERNAME" ] || [ -z "$STEAM_PASSWORD" ]; then
    echo -e "${RED}Error: Username and password cannot be empty${NC}"
    exit 1
  fi
  
  echo -e "${GREEN}Creating bot configuration file...${NC}"
  
  cat > "/opt/asf/config/$BOT_NAME.json" << EOLL
{
  "SteamLogin": "$STEAM_USERNAME",
  "SteamPassword": "$STEAM_PASSWORD",
  "Enabled": true,
  "UseNewerAuthenticatorFormat": true,
  "SteamAuthenticator": $MA_CONTENT
}
EOLL
  
  chmod 600 "/opt/asf/config/$BOT_NAME.json"
  chown 1000:1000 "/opt/asf/config/$BOT_NAME.json"
  
  echo -e "${GREEN}Bot configuration file created at /opt/asf/config/$BOT_NAME.json${NC}"
  echo -e "${GREEN}Restart ASF to apply changes:${NC}"
  echo -e "${YELLOW}cd /opt/asf && docker compose down && docker compose up -d${NC}"
  
  echo -e "${BLUE}Would you like to restart ASF now? (y/n)${NC}"
  read -n 1 -r RESTART_ASF
  echo -e ""
  
  if [[ $RESTART_ASF =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Restarting ASF...${NC}"
    cd /opt/asf && docker compose down && docker compose up -d
    echo -e "${GREEN}ASF restarted. You can now access your bot at https://${DOMAIN}${NC}"
  fi
else
  echo -e "${GREEN}No problem! You can create the configuration file manually using the instructions above.${NC}"
fi
EOL

  chmod +x /opt/asf/asf-auth-helper.sh
  chmod +x /opt/asf/asf-import-mafile.sh
  
  # Set proper permissions
  echo -e "${GREEN}Setting permissions...${NC}"
  chmod -R 755 /opt/asf
  chown -R 1000:1000 /opt/asf/config
  chown -R 1000:1000 /opt/asf/plugins

  # Start services
  echo -e "${GREEN}Starting services...${NC}"
  cd /opt/asf
  docker compose up -d
  sleep 3
  
  if [ "$WEB_SERVER" = "apache2" ]; then
    systemctl start apache2
  elif [ "$WEB_SERVER" = "nginx" ]; then
    systemctl start nginx
  fi

  # Display information
  echo -e "${GREEN}============================================${NC}"
  if [ "$ASF_ALREADY_INSTALLED" = true ]; then
    echo -e "${GREEN}ASF update completed successfully!${NC}"
  else
    echo -e "${GREEN}ASF installation completed successfully!${NC}"
  fi
  echo -e "${GREEN}============================================${NC}"
  echo -e "You can access ASF securely at: ${YELLOW}https://${DOMAIN}${NC}"
  echo -e ""
  echo -e "${YELLOW}IMPORTANT:${NC} Security credentials:"
  echo -e "1. Web interface password: ${ASF_IPC_PASSWORD}"
  echo -e "2. ASF encryption key: ${ASF_CRYPT_KEY}"
  echo -e ""
  echo -e "${GREEN}Bot Configuration Instructions:${NC}"
  echo -e "1. Access the ASF web interface at: ${YELLOW}https://${DOMAIN}${NC}"
  echo -e "2. Go to 'Bot Management' and click 'Add new bot'"
  echo -e "3. Configure your bot with your Steam credentials and other settings"
  echo -e ""
  echo -e "${BLUE}Steam Guard Authentication:${NC}"
  echo -e "When a Steam Guard code is required, you can enter it via the web interface:"
  echo -e "1. Access the command line in the web interface (IPC tab)"
  echo -e "2. When prompted for a code, you can use the '2fa [botname] <code>' command"
  echo -e "3. Or use the 'input [botname] <code>' command for other authentication requests"
  echo -e ""
  echo -e "For easier authentication monitoring, run the helper script:"
  echo -e "  ${YELLOW}sudo bash /opt/asf/asf-auth-helper.sh${NC}"
  echo -e "This script will watch for authentication requests and give you exact commands to use."
  echo -e ""
  echo -e "${BLUE}Importing Steam Desktop Authenticator .maFile:${NC}"
  echo -e "To import an existing .maFile from Steam Desktop Authenticator:"
  echo -e "  ${YELLOW}sudo bash /opt/asf/asf-import-mafile.sh${NC}"
  echo -e "This script will guide you through the process of importing your .maFile."
  echo -e ""
  echo -e "For accounts with mobile authenticator, you can add your shared secret to avoid manual codes:"
  echo -e "1. In your bot configuration add: 'TwoFactorAuthentication': true"
  echo -e "2. Add your shared secret: 'AuthenticatorSecret': 'YOUR_SHARED_SECRET'"
  echo -e ""
  echo -e "For more information about ASF configuration, visit:"
  echo -e "${YELLOW}https://github.com/JustArchiNET/ArchiSteamFarm/wiki/Configuration${NC}"
  echo -e ""
  echo -e "To restart ASF after making changes:"
  echo -e "  cd /opt/asf && docker compose down && docker compose up -d"
  echo -e ""
  echo -e "${YELLOW}If you encounter any issues with the web interface, check:${NC}"
  echo -e "1. ASF logs: ${GREEN}docker logs asf${NC}"
  
  if [ "$WEB_SERVER" = "apache2" ]; then
    echo -e "2. Apache error logs: ${GREEN}tail -f /var/log/apache2/asf-error.log${NC}"
  elif [ "$WEB_SERVER" = "nginx" ]; then
    echo -e "2. Nginx error logs: ${GREEN}tail -f /var/log/nginx/asf-error.log${NC}"
  fi
}

# Function to configure Apache
configure_apache() {
  echo -e "${GREEN}Configuring Apache...${NC}"
  
  # Create simplified Apache virtual host for ASF
  cat > /etc/apache2/sites-available/asf-${DOMAIN}.conf << EOL
<VirtualHost *:80>
    ServerName ${DOMAIN}
    Redirect permanent / https://${DOMAIN}/
</VirtualHost>

<VirtualHost *:443>
    ServerName ${DOMAIN}
    ServerAdmin webmaster@${MAIN_DOMAIN}

    SSLEngine on
    SSLCertificateFile /etc/ssl/cert.pem
    SSLCertificateKeyFile /etc/ssl/key.pem

    ProxyPass / http://localhost:${ASF_PORT}/
    ProxyPassReverse / http://localhost:${ASF_PORT}/

    ErrorLog \${APACHE_LOG_DIR}/asf-error.log
    CustomLog \${APACHE_LOG_DIR}/asf-access.log combined
</VirtualHost>
EOL

  # Enable the site if not already enabled
  if ! a2query -s asf-${DOMAIN} &> /dev/null; then
    echo -e "${GREEN}Enabling Apache virtual host...${NC}"
    a2ensite asf-${DOMAIN}
  fi
}

# Function to configure Nginx
configure_nginx() {
  echo -e "${GREEN}Configuring Nginx...${NC}"
  
  # Create simplified Nginx server block for ASF
  cat > /etc/nginx/sites-available/asf-${DOMAIN} << EOL
server {
    listen 80;
    server_name ${DOMAIN};
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name ${DOMAIN};

    ssl_certificate /etc/ssl/cert.pem;
    ssl_certificate_key /etc/ssl/key.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    
    location / {
        proxy_pass http://localhost:${ASF_PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    error_log /var/log/nginx/asf-error.log;
    access_log /var/log/nginx/asf-access.log;
}
EOL

  # Create symlink to enable the site
  if [ ! -f /etc/nginx/sites-enabled/asf-${DOMAIN} ]; then
    echo -e "${GREEN}Enabling Nginx server block...${NC}"
    ln -s /etc/nginx/sites-available/asf-${DOMAIN} /etc/nginx/sites-enabled/
  fi
}

# Main installation sequence
mkdir -p /opt/asf

# Setup .env file first
setup_env_file

# Install Docker
install_docker

# Install Web Server
install_web_server

# Setup ASF
setup_asf

echo -e "${GREEN}Installation complete!${NC}"
