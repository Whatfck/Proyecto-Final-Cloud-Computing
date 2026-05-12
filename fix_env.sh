#!/bin/bash
set -e

cd infra/terraform
DB_ENDPOINT=$(terraform output -raw marketplace_db_endpoint)
S3_BUCKET=$(terraform output -raw product_images_bucket_name)
ORDERS_QUEUE=$(terraform output -raw orders_queue_url)
MAIN_ID=$(terraform output -raw web_main_instance_id)
CANARY_ID=$(terraform output -raw web_canary_instance_id)

cd ../..

ENV_CONTENT="AWS_REGION=us-east-1
DB_HOST=$DB_ENDPOINT
DB_PORT=5432
DB_USER=marketplace_user
DB_PASSWORD=Grupo3Demo2026!
DB_NAME=grupo3_marketplace
S3_BUCKET_NAME=$S3_BUCKET
ORDERS_QUEUE_URL=$ORDERS_QUEUE
PORT=3000
NODE_ENV=production"

echo "Writing env via SSM..."
aws ssm send-command \
    --region us-east-1 \
    --document-name "AWS-RunShellScript" \
    --targets "Key=instanceids,Values=$MAIN_ID,$CANARY_ID" \
    --parameters 'commands=["cat > /opt/app/backend/.env <<EOF'"\n$ENV_CONTENT\n"'EOF", "systemctl restart marketplace"]' \
    --timeout-seconds 60 > /dev/null

echo "✅ Environment fixed and service restarted"
