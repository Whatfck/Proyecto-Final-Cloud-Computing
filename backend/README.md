# Backend Marketplace - Grupo 3

Backend Express.js que sirve el API del marketplace con integración AWS (S3, SQS, RDS).

## Instalación local

```bash
cd backend
npm install
```

## Configuración

Copia `.env.example` a `.env` y llena los valores:

```bash
cp .env.example .env
```

### Variables de entorno

- **PORT**: Puerto donde corre el backend (default: 3000)
- **AWS_REGION**: Región AWS (default: us-east-1)
- **AWS_ACCESS_KEY_ID**: Tu access key AWS
- **AWS_SECRET_ACCESS_KEY**: Tu secret key AWS
- **DB_HOST**: Host de RDS (ej: grupo3-marketplace.c123456.us-east-1.rds.amazonaws.com)
- **DB_USER**: Usuario RDS (default: admin)
- **DB_PASSWORD**: Password RDS
- **DB_NAME**: Nombre de la BD (default: marketplace)
- **S3_BUCKET_NAME**: Bucket S3 para imágenes (default: grupo3-marketplace-product-images)
- **ORDERS_QUEUE_URL**: URL de la cola SQS (ej: https://sqs.us-east-1.amazonaws.com/123456/orders)

## Uso

### Desarrollo local (sin AWS)

```bash
npm run dev
```

El backend correrá en `http://localhost:3000` y usará datos en memoria si RDS no está disponible.

### Producción (con AWS)

Configura las variables de entorno en `.env` y ejecuta:

```bash
npm start
```

## API Endpoints

### Productos

**GET `/api/products`**
- Retorna lista de todos los productos
- Respuesta: `[{ id, name, description, price, stock, imageUrl, ... }]`

**POST `/api/products`**
- Crea un nuevo producto con imagen (multipart/form-data)
- Body:
  - `name` (string, required)
  - `description` (text, required)
  - `price` (number, required)
  - `stock` (int, required)
  - `image` (file, optional)
- Respuesta: `{ success: true, product: {...} }`

### Órdenes

**GET `/api/orders`**
- Retorna lista de todas las órdenes
- Respuesta: `[{ id, productId, quantity, total, status, ... }]`

**POST `/api/orders`**
- Crea una nueva orden
- Body:
  ```json
  {
    "productId": 1,
    "productName": "Laptop",
    "quantity": 2,
    "total": 2400,
    "buyerName": "Juan",
    "buyerEmail": "juan@example.com"
  }
  ```
- La orden se envía automáticamente a SQS para procesamiento asincrónico
- Respuesta: `{ success: true, order: {...} }`

### Health

**GET `/health`**
- Verifica estado del backend
- Respuesta: `{ status: "ok", database: "connected|disconnected", ... }`

## Características

- ✅ Frontend Vue.js + Bootstrap servido desde Express
- ✅ Upload de imágenes a S3
- ✅ Órdenes a SQS para procesamiento asincrónico
- ✅ Datos en memoria si RDS no disponible
- ✅ Pool de conexiones RDS
- ✅ Error handling robusto

## Estructura

```
backend/
├── server.js           # Servidor principal
├── package.json        # Dependencias
├── .env.example        # Variables de ejemplo
└── .gitignore          # Archivos a ignorar
```

## Notas

- Las imágenes se guardan en S3 con URLs públicas
- Las órdenes se encolan en SQS y son procesadas por Lambda
- El backend está optimizado para funcionar en EC2 con Terraform
- Soporta múltiples instancias con ALB

