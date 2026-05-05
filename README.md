# Proyecto Final Cloud Computing 

### 3. Marketplace con Procesamiento de Pagos y Notificaciones

**Servicios:** EC2 + ALB + Lambda + RDS + SQS + SNS + S3

**Descripción:** Vendedores publican productos (imágenes en S3, datos en RDS). Las órdenes entran por API Gateway → Lambda → SQS. Otra Lambda consume la cola, procesa el pago (simulado) y publica en SNS para notificar por email/SMS.

- Implementar el patrón **Fan-out:** SNS tiene tres suscriptores distintos cuando llega una orden: (1) SQS cola de procesamiento de pago, (2) SQS cola de notificación al vendedor, (3) Lambda directa para actualizar inventario en RDS. Cada suscriptor debe tener un filter policy en SNS para recibir solo los mensajes que le corresponden según el tipo de evento.

- La cola principal de SQS debe tener configurada una **Dead Letter Queue** (DLQ) con maxReceiveCount: 3. Una Lambda separada debe monitorear la DLQ cada 5 minutos via EventBridge, leer los mensajes fallidos, registrar el error en RDS y notificar al administrador por SNS.

- EC2 con NGINX debe estar configurado como **reverse proxy con upstream ponderado:** 70% del tráfico al servidor de la app principal, 30% a una instancia "canary" con la versión nueva. Demostrar el cambio de pesos sin downtime.

- Las imágenes de productos en S3 deben pasar por una **Lambda de validación** (tamaño máximo, formato permitido, sin contenido explícito usando Rekognition) antes de quedar disponibles. Si la validación falla, mover el objeto a un prefijo /rejected/ y notificar al vendedor.

---

## Instrucciones de uso

### Requisitos

Instala lo siguiente en el equipo:

- Git
- Terraform 1.6 o superior
- AWS CLI v2

Verifica versiones:

```bash
git --version
terraform version
aws --version
```

### Clonar el repositorio

```bash
git clone <URL_DEL_REPO>
cd Proyecto-Final-Cloud-Computing
```

### Configurar credenciales AWS

```bash
aws configure
```

Valores sugeridos:

- AWS Access Key ID: tu access key
- AWS Secret Access Key: tu secret key
- Default region name: us-east-1
- Default output format: json

Verifica identidad:

```bash
aws sts get-caller-identity
```

### Desplegar infraestructura

```bash
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform fmt -recursive
terraform validate
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

### Revisar resultados

```bash
terraform output
terraform state list
```

### Eliminar recursos

```bash
terraform destroy -var-file=terraform.tfvars
```

## Flujo de trabajo del grupo

1. Terraform crea la red, el balanceador, las EC2, S3, SQS, SNS, IAM, Lambda y RDS.
2. Las EC2 arrancan con NGINX y quedan detrás del ALB.
3. El frontend se sirve desde la capa web del proyecto.
4. El vendedor publica productos e imágenes.
5. El comprador crea una orden.
6. La orden se procesa de forma asíncrona.
7. SNS distribuye eventos a las colas y Lambdas suscritas.
8. RDS conserva la información del marketplace.

## Documentación complementaria

- [Flujo de funcionamiento final](FLUJO_FUNCIONAMIENTO_FINAL.md)

## Notas

- Usa `terraform destroy` al terminar pruebas para evitar recursos activos.
- S3 se usa para imágenes de productos y artefactos del frontend.
- El frontend y la capa web se sirven mediante EC2 Ubuntu con NGINX detrás de un ALB.

