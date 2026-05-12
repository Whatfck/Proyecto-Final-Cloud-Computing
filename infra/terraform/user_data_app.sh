#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

# Terraform variables
AWS_REGION="${aws_region}"
AWS_ACCESS_KEY_ID="${aws_access_key_id}"
AWS_SECRET_ACCESS_KEY="${aws_secret_key}"
DB_ENDPOINT="${db_endpoint}"
DB_PORT="${db_port}"
DB_PASSWORD="${db_password}"
S3_BUCKET="${s3_bucket_name}"
BUILDS_BUCKET="${builds_bucket_name}"
ORDERS_QUEUE_URL="${orders_queue_url}"
APP_ROLE="${app_role}"

LOG_FILE="/var/log/marketplace-setup.log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "=== Starting Marketplace Node.js Application Setup ($${APP_ROLE}) ==="
apt-get update -qq
apt-get install -y curl wget git awscli

curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

mkdir -p /opt/app
cd /opt/app

export AWS_ACCESS_KEY_ID="$${AWS_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="$${AWS_SECRET_ACCESS_KEY}"
export AWS_REGION="$${AWS_REGION}"

if [ -n "$${BUILDS_BUCKET}" ]; then
  if aws s3 cp "s3://$${BUILDS_BUCKET}/backend.tar.gz" /tmp/backend.tar.gz 2>/dev/null; then
    tar -xzf /tmp/backend.tar.gz
    rm -f /tmp/backend.tar.gz
  else
    git clone https://github.com/Whatfck/Proyecto-Final-Cloud-Computing.git . 2>/dev/null || mkdir -p backend frontend infra
    cd backend && npm install --production && cd ..
  fi
fi

mkdir -p /opt/app/backend
cat > /opt/app/backend/.env << EOF
AWS_REGION=$${AWS_REGION}
AWS_ACCESS_KEY_ID=$${AWS_ACCESS_KEY_ID}
AWS_SECRET_ACCESS_KEY=$${AWS_SECRET_ACCESS_KEY}
DB_HOST=$${DB_ENDPOINT}
DB_PORT=$${DB_PORT}
DB_USER=grupo3admin
DB_PASSWORD=$${DB_PASSWORD}
DB_NAME=grupo3_marketplace
S3_BUCKET_NAME=$${S3_BUCKET}
ORDERS_QUEUE_URL=$${ORDERS_QUEUE_URL}
PORT=3000
NODE_ENV=production
APP_ROLE=$${APP_ROLE}
EOF
chmod 600 /opt/app/backend/.env

# Local deploy script
cat > /opt/app/backend/deploy_local.sh << EOF
#!/bin/bash
export AWS_REGION=$${AWS_REGION}
export AWS_ACCESS_KEY_ID=$${AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=$${AWS_SECRET_ACCESS_KEY}
aws s3 cp s3://$${BUILDS_BUCKET}/backend.tar.gz /tmp/backend.tar.gz
cd /opt/app
tar -xzf /tmp/backend.tar.gz
rm /tmp/backend.tar.gz
cd backend && npm install --production
systemctl restart marketplace
EOF
chmod +x /opt/app/backend/deploy_local.sh

cat > /etc/systemd/system/marketplace.service << 'SVCEOF'
[Unit]
Description=Marketplace Backend
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/app/backend
EnvironmentFile=/opt/app/backend/.env
ExecStart=/usr/bin/node server.js
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=marketplace

[Install]
WantedBy=multi-user.target
SVCEOF

systemctl daemon-reload
systemctl enable marketplace.service
systemctl start marketplace.service
echo "✓ Backend setup complete"
