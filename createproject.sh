#!/bin/bash

# Define colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

# Ask user for project name
read -p "Enter the project name: " PROJECT_NAME

# Check if input is not empty and doesn't containt spaces
if [[ -z "$PROJECT_NAME" || "$PROJECT_NAME" =~ [[:space:]] ]]; then
    echo -e "${YELLOW}Project name cannot be empty or contain spaces.${RESET}"
    exit 1
fi

# Define variables
PROJECT_DIR="/var/www/html/$PROJECT_NAME"
DB_NAME="$PROJECT_NAME"
DB_USER="root"
DB_PASSWORD=""
DB_HOST="localhost"
WP_HOME="http://$PROJECT_NAME.local"
WP_SITEURL="http://$PROJECT_NAME.local/wp"
APACHE_CONF="/etc/apache2/sites-available/$PROJECT_NAME.conf"
ETC_HOSTS="/etc/hosts"

# Check if the project directory already exists
if [ -d "$PROJECT_DIR" ]; 
then
    echo -e "${YELLOW}$PROJECT_NAME already exists. Please choose another name.${RESET}"
    exit 1
fi

# Create the directory using bedrock
composer create-project roots/bedrock "$PROJECT_DIR"

# Ensure Apache can read and write to the Bedrock directory
sudo chown -R www-data:www-data "$PROJECT_DIR"
sudo find "$PROJECT_DIR" -type d -exec chmod 755 {} \;
sudo find "$PROJECT_DIR" -type f -exec chmod 755 {} \;

# Create a new Apache configuration for the project
echo "Creating Apache configuration for Bedrock"
sudo bash -c "cat > $APACHE_CONF <<EOL

<VirtualHost *:80>
    ServerName "$PROJECT_NAME".local
    DocumentRoot "$PROJECT_DIR"/web

    <Directory "$PROJECT_DIR"/web>
	Options Indexes FollowSymLinks
	AllowOverride All
	Require all granted
    </Directory>

    ErrorLog /var/log/apache2/"$PROJECT_NAME"-error.log
    CustomLog /var/log/apache2/"$PROJECT_NAME"-access.log combined
</VirtualHost>
EOL"

# Give www-data permissions to write to /var/log/apache2/ directory
sudo usermod -a -G adm www-data

# Enable the new site and required modules
echo "Enablind the new site and required Apache modules..."
sudo a2ensite "$PROJECT_NAME".conf
sudo a2enmod rewrite

# Add the project to /etc/hosts if it doesn't exist
echo "Adding $PROJECT_NAME.local to /etc/hosts..."
if ! grep -q "$PROJECT_NAME.local" /etc/hosts; then
    sudo bash -c "echo '127.0.0.1 $PROJECT_NAME.local' >> /etc/hosts"
fi

# Reload Apache for changes to take effect
systemctl reload apache2

echo -e "${GREEN}$PROJECT_NAME setup completed! You can access it at http://$PROJECT_NAME.local${RESET}"
