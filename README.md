# ssl-certificat-configuration

Step-by-Step Instructions:
Edit the Script: Update the DOMAIN_NAME variable (Line 8) with your actual domain.
Upload to Manager: Move the script to your Wazuh server via SSH or WinSCP.
Make it Executable:
code
Bash
chmod +x configure_wazuh_ssl.sh
Execute the Script:
code
Bash
sudo ./configure_wazuh_ssl.sh
SOC Analyst Security & Operations Note:
Auto-Renewal Verification: Certbot adds a cron job automatically, but my script appends the renew_hook. This is critical because if the certificate renews but the wazuh-dashboard service isn't restarted, the dashboard will still show the old expired certificate.
Port 80 Requirement: Keep Port 80 open in your Azure NSG. Certbot's standalone mode uses Port 80 to verify domain ownership during the challenge process.
Dry Run Test: Once the script finishes, I recommend running the following command to ensure renewal will work in the future:
code
Bash
certbot renew --dry-run
