#!/bin/bash
set -e

REGION=${1:-"us-east-1"}

echo "=== Creando paquete del Backend ==="
tar -czvf backend.tar.gz backend/ frontend/

echo "=== Subiendo a S3 ==="
# Intentamos obtener el bucket dinámicamente si terraform ya fue aplicado
cd infra/terraform
BUCKET_NAME=$(terraform output -raw builds_bucket_name 2>/dev/null || true)
# Limpiar advertencias de Terraform (como "Warning: No outputs found")
if [[ "$BUCKET_NAME" == *"Warning"* || "$BUCKET_NAME" == *"No outputs found"* ]]; then
  BUCKET_NAME=""
fi
cd ../..

if [ -z "$BUCKET_NAME" ]; then
  echo "⚠️  No se pudo determinar el bucket. Aplica Terraform primero:"
  echo "  cd infra/terraform && terraform init && terraform apply"
  echo "Luego vuelve a correr este script."
  exit 1
fi

echo "Subiendo a s3://${BUCKET_NAME}/backend.tar.gz"
aws s3 cp backend.tar.gz s3://${BUCKET_NAME}/backend.tar.gz --region ${REGION}

echo "✅ Backend subido exitosamente."
