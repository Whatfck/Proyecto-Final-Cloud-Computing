# Funcionamiento Final Esperado

## Objetivo

Este documento explica cómo debería comportarse el marketplace una vez terminada la integración completa. La arquitectura está pensada para AWS y combina frontend en EC2 con NGINX y ALB, backend en Node.js, base de datos PostgreSQL en RDS, almacenamiento en S3 y mensajería asíncrona con SQS, SNS y Lambda.

## Vista general

El sistema sigue un recorrido simple para el usuario, pero internamente separa claramente las responsabilidades:

1. El usuario accede por el Application Load Balancer.
2. El ALB entrega tráfico a las instancias EC2 con NGINX.
3. NGINX sirve el frontend y reenvía las llamadas API al backend.
4. El backend registra productos, órdenes e imágenes.
5. La orden se guarda en base de datos y se publica en la cola.
6. Lambda y SNS procesan los eventos posteriores de forma desacoplada.

## Flujo de usuario

### 1. Inicio

El usuario abre la URL pública del ALB. Desde ahí ve la interfaz del marketplace sin conectarse directamente a la instancia EC2.

### 2. Publicación de producto

El vendedor completa el formulario de producto y adjunta una imagen. El backend valida el archivo, lo sube a S3 y persiste la información del producto en PostgreSQL.

### 3. Creación de orden

El comprador selecciona un producto, define la cantidad y confirma la compra. El backend verifica stock, guarda la orden y la envía a SQS para procesarla de forma asíncrona.

### 4. Procesamiento posterior

Las funciones Lambda reaccionan a los eventos para actualizar inventario, notificar al vendedor y dejar trazabilidad del procesamiento.

## Capas del sistema

### Capa web

- El ALB expone el sistema hacia internet.
- EC2 Ubuntu ejecuta NGINX como reverse proxy.
- El frontend se sirve desde la propia capa web del proyecto.

### Capa de aplicación

- El backend Node.js expone los endpoints REST.
- Las órdenes se validan antes de persistirse.
- Las imágenes se suben a S3 mediante el backend.

### Capa de datos

- RDS PostgreSQL guarda productos, órdenes y estados.
- S3 conserva imágenes de productos y artefactos del backend.

### Capa asíncrona

- SQS desacopla la creación de la orden del procesamiento.
- SNS hace fan-out hacia colas y funciones específicas.
- Lambda procesa eventos, actualiza inventario y notifica.

## Arranque esperado

Cuando Terraform crea la infraestructura, el sistema debería arrancar en este orden:

1. Terraform crea red, subredes, tablas de ruteo, seguridad, S3, SQS, SNS, IAM, Lambda y RDS.
2. Las instancias EC2 arrancan con `user_data`.
3. `user_data` instala dependencias, configura variables de entorno y levanta NGINX.
4. El backend intenta conectar a PostgreSQL y crea las tablas si no existen.
5. Si la base no responde, el backend puede seguir en modo memoria para no bloquear la interfaz.

## Flujo de datos

### Productos

- El formulario envía nombre, descripción, precio, stock e imagen.
- El backend genera un nombre único para el archivo.
- La imagen se sube a S3.
- Los datos del producto se guardan en PostgreSQL.

### Órdenes

- El comprador envía producto, cantidad y datos del comprador.
- El backend valida el stock contra lo que tiene cargado en memoria o en base.
- La orden se inserta en PostgreSQL.
- La orden se publica en SQS para su procesamiento.

### Eventos

- SNS distribuye mensajes hacia los consumidores suscritos.
- Lambda puede actualizar inventario, procesar órdenes o notificar vendedores.
- Las colas con DLQ conservan los errores para revisión posterior.

## Estado esperado por componente

- Frontend accesible desde el ALB.
- Backend respondiendo en la EC2 detrás de NGINX.
- PostgreSQL disponible en RDS.
- S3 con bucket de imágenes y bucket de builds.
- SQS con cola principal y DLQ.
- SNS con suscriptores para fan-out.
- Lambda preparada para tareas automáticas y procesamiento posterior.

## Manejo de fallos

- Si PostgreSQL no está disponible, el backend sigue con datos en memoria.
- Si S3 no responde, la imagen no se adjunta al producto pero el resto del flujo puede continuar.
- Si la publicación a SQS falla, la orden sigue persistida y el error debe revisarse en logs.
- Si una Lambda falla repetidamente, la DLQ debe retener el mensaje para análisis.

## Partes que todavía faltan o están en progreso

- Hacer que todas las Lambdas usen exactamente el mismo contrato de variables de entorno.
- Verificar el flujo completo con una ejecución real en AWS después de cada cambio grande.
- Completar la validación de imágenes con reglas más estrictas si se quiere un flujo más cercano a producción.
- Afinar el despliegue para que el backend use siempre el build de S3 cuando exista.

## Resultado final esperado

Cuando todo está bien configurado, el sistema debe permitir:

- navegar productos,
- publicar productos con imágenes,
- crear órdenes,
- persistir datos en PostgreSQL,
- procesar eventos de forma asíncrona,
- y borrar la infraestructura con Terraform al terminar.