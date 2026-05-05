# Flujo de Funcionamiento Final

## Resumen general

El sistema opera como un marketplace sobre AWS donde el frontend se sirve desde EC2 con NGINX detrás de un ALB, mientras el backend procesa órdenes, inventario y notificaciones mediante Lambda, SQS, SNS y RDS.

## Flujo de usuario

1. El usuario abre el frontend desde el ALB.
2. El ALB distribuye la carga entre varias instancias EC2 Ubuntu con NGINX.
3. El vendedor publica productos y sube imágenes a S3.
4. La aplicación registra la información de producto en RDS.
5. El comprador crea una orden desde la interfaz.
6. La orden entra al flujo asincrónico por SQS.
7. Lambda procesa la orden, simula el pago y actualiza el estado.
8. SNS distribuye los eventos a las colas y funciones suscritas.
9. La Lambda de inventario actualiza stock y la de notificación informa al vendedor.

## Flujo de infraestructura

### Capa web

- Un Application Load Balancer recibe tráfico HTTP.
- El ALB reparte peticiones entre varias EC2 Ubuntu.
- Cada EC2 ejecuta NGINX y sirve el frontend.
- El arranque de la instancia deja el sitio listo automáticamente.

### Capa de datos

- RDS MySQL guarda productos, órdenes, inventario y estados.
- S3 conserva imágenes de productos y artefactos del frontend.

### Capa de mensajería

- SQS desacopla el ingreso de órdenes del procesamiento.
- La cola principal usa DLQ para fallos.
- SNS hace fan-out hacia colas y funciones específicas.

### Capa de cómputo

- Lambda procesa órdenes.
- Lambda actualiza inventario.
- Lambda notifica al vendedor.

## Flujo de despliegue

1. Terraform crea red, seguridad, ALB, EC2, S3, SQS, SNS, IAM, Lambda y RDS.
2. Las instancias EC2 arrancan con `user_data` y levantan NGINX.
3. El frontend queda disponible por el ALB.
4. Las órdenes entran por la aplicación y viajan por la cola.
5. Las funciones Lambda ejecutan el procesamiento y la notificación.

## Estado final esperado

- Frontend accesible por ALB.
- EC2 Ubuntu con NGINX activa detrás del balanceador.
- S3 con imágenes y artefactos.
- RDS con la información del marketplace.
- SQS y SNS coordinando el procesamiento.
- Lambda resolviendo las tareas automáticas del sistema.