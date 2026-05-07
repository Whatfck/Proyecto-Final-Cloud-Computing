#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

# Terraform variables (interpolated by templatefile)
AWS_REGION="${aws_region}"
AWS_ACCESS_KEY_ID="${aws_access_key_id}"
AWS_SECRET_ACCESS_KEY="${aws_secret_key}"
DB_ENDPOINT="${db_endpoint}"
DB_PORT="${db_port}"
DB_PASSWORD="${db_password}"
S3_BUCKET="${s3_bucket_name}"
BUILDS_BUCKET="${builds_bucket_name}"
ORDERS_QUEUE_URL="${orders_queue_url}"

# Logging setup
LOG_FILE="/var/log/marketplace-setup.log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo "=== Starting Marketplace Node.js Application Setup ==="
echo "Timestamp: $(date)"

# 1. Update system and install dependencies
echo "[1/8] Updating system packages..."
apt-get update -qq
apt-get install -y curl wget git awscli

# 2. Install Node.js 18 LTS
echo "[2/8] Installing Node.js 18 LTS..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

echo "Node.js version: $(node --version)"
echo "npm version: $(npm --version)"

# 3. Create application directory
echo "[3/8] Setting up application directory..."
mkdir -p /opt/app
cd /opt/app

# 4. Configure AWS credentials for S3 access
export AWS_ACCESS_KEY_ID="$${AWS_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="$${AWS_SECRET_ACCESS_KEY}"
export AWS_REGION="$${AWS_REGION}"

# 5. Deploy application code
echo "[4/8] Deploying application code..."

DEPLOYMENT_METHOD="fallback"

# Try to download pre-built backend from S3 (fast deployment: ~30 seconds)
if [ -n "$${BUILDS_BUCKET}" ]; then
  if aws s3 ls "s3://$${BUILDS_BUCKET}/backend.tar.gz" 2>/dev/null >/dev/null; then
    echo "✓ Found pre-built backend in S3 bucket: $${BUILDS_BUCKET}"
    echo "  Downloading pre-built backend..."
    
    if aws s3 cp "s3://$${BUILDS_BUCKET}/backend.tar.gz" /tmp/backend.tar.gz 2>/dev/null; then
      echo "  Extracting backend..."
      tar -xzf /tmp/backend.tar.gz
      rm -f /tmp/backend.tar.gz
      DEPLOYMENT_METHOD="s3-build"
      echo "✓ Pre-built backend deployed successfully (deployment: ~30 seconds)"
    else
      echo "✗ Failed to download from S3, falling back to git clone..."
    fi
  else
    echo "ⓘ Pre-built backend not found in S3 bucket: $${BUILDS_BUCKET}"
    echo "  Use: npm run build && aws s3 cp build.tar.gz s3://$${BUILDS_BUCKET}/"
    echo "  Falling back to git clone..."
  fi
fi

# Fallback: Clone repository and install dependencies (slow deployment: ~5-10 minutes)
if [ "$DEPLOYMENT_METHOD" = "fallback" ]; then
  echo "→ Git clone and npm install method (first deployment, ~5-10 minutes)..."
  
  git clone https://github.com/[TU_USUARIO]/Proyecto-Final-Cloud-Computing.git . 2>/dev/null || {
    echo "⚠ Could not clone repository. You may need to upload files manually."
    mkdir -p backend frontend infra
  }
  
  echo "  Installing npm dependencies (this may take several minutes)..."
  cd backend && npm install --production && cd ..
  
  echo "✓ Repository cloned and dependencies installed (deployment: ~5-10 minutes)"
fi

# 6. Create environment file
echo "[5/8] Creating environment configuration..."
mkdir -p /opt/app/backend
cat > /opt/app/backend/.env << EOF
# AWS Configuration
AWS_REGION=$${AWS_REGION}
AWS_ACCESS_KEY_ID=$${AWS_ACCESS_KEY_ID}
AWS_SECRET_ACCESS_KEY=$${AWS_SECRET_ACCESS_KEY}

# RDS Database Configuration
DB_HOST=$${DB_ENDPOINT}
DB_PORT=$${DB_PORT}
DB_USER=grupo3admin
DB_PASSWORD=$${DB_PASSWORD}
DB_NAME=grupo3_marketplace

# S3 Configuration
S3_BUCKET_NAME=$${S3_BUCKET}

# SQS Configuration
ORDERS_QUEUE_URL=$${ORDERS_QUEUE_URL}

# Server Configuration
PORT=3000
NODE_ENV=production
EOF

chmod 600 /opt/app/backend/.env
echo "✓ Environment configuration created"

# 7. Setup systemd service
echo "[6/8] Setting up systemd service..."
cat > /etc/systemd/system/marketplace.service << 'EOF'
[Unit]
Description=Marketplace Node.js Backend
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/app/backend
ExecStart=/usr/bin/node server.js
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=marketplace
Environment="NODE_ENV=production"
Environment="PORT=3000"

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable marketplace.service
systemctl start marketplace.service
echo "✓ Systemd service configured and started"

# 8. Setup NGINX reverse proxy
echo "[7/8] Setting up NGINX reverse proxy..."
apt-get install -y nginx

cat > /etc/nginx/sites-available/default << 'NGINX_EOF'
upstream marketplace {
    server localhost:3000;
}

server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    
    client_max_body_size 5M;

    location / {
        proxy_pass http://marketplace;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
NGINX_EOF

systemctl enable nginx
systemctl restart nginx
echo "✓ NGINX reverse proxy configured"

# 9. Verify services
echo "[8/8] Verifying services..."
sleep 3
systemctl status marketplace --no-pager | head -5
systemctl status nginx --no-pager | head -5

echo ""
echo "════════════════════════════════════════════════════════"
echo "✓ Marketplace Application Setup Complete!"
echo "════════════════════════════════════════════════════════"
echo "Deployment Method: $DEPLOYMENT_METHOD"
echo "Backend running on: http://localhost:3000"
echo "Exposed via NGINX on: port 80"
echo "S3 Builds Support: Enabled"
echo "Logs: $LOG_FILE"
echo "════════════════════════════════════════════════════════"
