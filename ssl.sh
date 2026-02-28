#!/bin/bash

# ==============================================================================
# Wazuh SOC Expert - Let's Encrypt SSL Configuration Script
# Target: Wazuh Dashboard Node
# ==============================================================================

# 1. SET VARIABLES
DOMAIN_NAME="wazuh.cyberxpertz.online"  # <--- REPLACE WITH YOUR DOMAIN
DASHBOARD_CONF="/etc/wazuh-dashboard/opensearch_dashboards.yml"
CERT_DIR="/etc/wazuh-dashboard/certs"

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}[*] Starting Wazuh Dashboard SSL configuration for $DOMAIN_NAME...${NC}"

# 2. CHECK FOR ROOT
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[!] Error: This script must be run as root.${NC}"
   exit 1
fi

# 3. INSTALL CERTBOT VIA SNAP
echo -e "${GREEN}[*] Installing Certbot via Snap...${NC}"
apt-get update
apt-get install snapd -y
snap install core; snap refresh core
snap install --classic certbot
ln -sf /snap/bin/certbot /usr/bin/certbot

# 4. CONFIGURE FIREWALL
echo -e "${GREEN}[*] Opening Ports 80 and 443...${NC}"
ufw allow 443
ufw allow 80

# 5. GENERATE CERTIFICATE
echo -e "${GREEN}[*] Requesting Let's Encrypt Certificate...${NC}"
certbot certonly --standalone -d $DOMAIN_NAME --non-interactive --agree-tos -m admin@$DOMAIN_NAME

if [ ! -d "/etc/letsencrypt/live/$DOMAIN_NAME" ]; then
    echo -e "${RED}[!] Error: Certificate generation failed. Check your DNS and Port 80.${NC}"
    exit 1
fi

# 6. COPY CERTIFICATES TO WAZUH DIRECTORY
echo -e "${GREEN}[*] Deploying certificates to Wazuh Dashboard...${NC}"
cp /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem $CERT_DIR/privkey.pem
cp /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem $CERT_DIR/fullchain.pem

# 7. UPDATE DASHBOARD CONFIGURATION
echo -e "${GREEN}[*] Updating opensearch_dashboards.yml...${NC}"
# Backup the original file
cp $DASHBOARD_CONF "$DASHBOARD_CONF.bak_ssl"

# Use sed to update the SSL paths
sed -i 's|server.ssl.key:.*|server.ssl.key: "/etc/wazuh-dashboard/certs/privkey.pem"|' $DASHBOARD_CONF
sed -i 's|server.ssl.certificate:.*|server.ssl.certificate: "/etc/wazuh-dashboard/certs/fullchain.pem"|' $DASHBOARD_CONF

# 8. SET PERMISSIONS
echo -e "${GREEN}[*] Setting correct file permissions...${NC}"
chown -R wazuh-dashboard:wazuh-dashboard /etc/wazuh-dashboard/
chmod -R 500 $CERT_DIR/
chmod 440 $CERT_DIR/privkey.pem $CERT_DIR/fullchain.pem

# 9. CONFIGURE AUTO-RENEWAL HOOK
echo -e "${GREEN}[*] Configuring auto-renewal hook...${NC}"
RENEW_FILE="/etc/letsencrypt/renewal/$DOMAIN_NAME.conf"
if [ -f "$RENEW_FILE" ]; then
    # Check if renew_hook already exists, if not, add it
    if ! grep -q "renew_hook" "$RENEW_FILE"; then
        echo "renew_hook = systemctl restart wazuh-dashboard" >> "$RENEW_FILE"
    fi
fi

# 10. RESTART SERVICE
echo -e "${GREEN}[*] Restarting Wazuh Dashboard...${NC}"
systemctl restart wazuh-dashboard

echo -e "${GREEN}==================================================================${NC}"
echo -e "${GREEN}[COMPLETE] Wazuh Dashboard is now secured with SSL!${NC}"
echo -e "${GREEN}URL: https://$DOMAIN_NAME${NC}"
echo -e "${GREEN}==================================================================${NC}"
