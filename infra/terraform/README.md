# Terraform Infraestructura Base

Este directorio contiene la infraestructura base del Grupo 3.

## Recursos incluidos
- VPC
- Subnets públicas y privadas
- Internet Gateway
- Route tables y asociaciones
- Security groups básicos
- Bucket S3 para imágenes de productos
- Cola SQS principal + DLQ
- Tópico SNS de eventos con suscripciones a SQS
- Rol IAM base para Lambdas del marketplace
- Base de datos RDS MySQL para el marketplace
- Lambdas para procesar órdenes, notificar vendedor y actualizar inventario
- Application Load Balancer con varias EC2 Ubuntu/Nginx detrás

## Flujo esperado
1. Copiar `terraform.tfvars.example` a `terraform.tfvars`.
2. Ejecutar `terraform init`.
3. Ejecutar `terraform plan`.
4. Ejecutar `terraform apply`.
5. Cuando ya no se necesite, ejecutar `terraform destroy`.

## Nota
No se usan scripts separados de borrado porque Terraform ya administra el ciclo completo de creación y destrucción de la infraestructura.
