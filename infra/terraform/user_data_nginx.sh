#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

MAIN_IP="${main_ip}"
CANARY_IP="${canary_ip}"

LOG_FILE="/var/log/nginx-setup.log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "=== Starting NGINX Reverse Proxy Setup ==="
apt-get update -qq
apt-get install -y nginx

cat > /etc/nginx/sites-available/default << NGINX_EOF
upstream marketplace {
    server $${MAIN_IP}:3000 weight=7;
    server $${CANARY_IP}:3000 weight=3;
}

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    client_max_body_size 5M;

    location / {
        proxy_pass http://marketplace;
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
NGINX_EOF

systemctl restart nginx

echo "✓ NGINX setup complete"
