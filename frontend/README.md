# Frontend Marketplace - Grupo 3

Frontend en Vue.js 3 + Bootstrap 5 para el marketplace. Se sirve desde Express en `localhost:3000`.

## Características

- ✅ **Interfaz responsiva** con Bootstrap 5
- ✅ **Reactividad en tiempo real** con Vue.js 3
- ✅ **Catálogo de productos** con imágenes
- ✅ **Upload de imágenes** a S3
- ✅ **Carrito de compras** (órdenes)
- ✅ **Estado de órdenes** en tiempo real
- ✅ **Sin build step** - CDN basado

## Estructura

```
frontend/
├── index.html          # App principal
├── js/
│   ├── api.js          # Cliente HTTP para comunicarse con backend
│   └── app.js          # Lógica de Vue.js
├── css/
│   └── style.css       # Estilos custom
└── README.md
```

## Cómo funciona

### Flujo de usuario

1. **Ver productos**: GET `/api/products`
2. **Publicar producto**: POST `/api/products` con datos + imagen
   - La imagen se sube a S3 automáticamente desde el backend
3. **Crear orden**: POST `/api/orders` con datos de compra
   - La orden se encola en SQS para procesamiento
4. **Ver estado**: GET `/api/orders` muestra órdenes

### Tecnologías

- **Vue.js 3** (CDN, sin build)
- **Bootstrap 5** (CDN para estilos)
- **Fetch API** para comunicarse con backend Express

## Páginas

### 1. Catálogo de Productos
- Lista todos los productos disponibles
- Muestra imagen, nombre, descripción, precio y stock
- Botón "Comprar" para seleccionar producto

### 2. Publicar Producto (Vender)
- Formulario para crear nuevo producto
- Input file para subir imagen
- Validación de datos

### 3. Mis Órdenes
- Ver órdenes existentes con estado
- Crear nueva orden desde producto seleccionado
- Estados: PENDING, PROCESSING, COMPLETED, FAILED

## Instalación

No requiere instalación - est servido por Express automáticamente.

```bash
cd backend
npm install
npm run dev
# Abre http://localhost:3000
```

## Variables disponibles

Todas las URLs de API son relativas al dominio actual:
```javascript
const API_BASE_URL = window.location.origin;
// En local: http://localhost:3000
// En AWS: https://tu-alb-dns.com
```

## API de componentes

### app.js

```javascript
// Data
- currentPage: 'products' | 'create-product' | 'orders'
- products: [{ id, name, description, price, stock, imageUrl }]
- orders: [{ id, product_id, quantity, total, status, ... }]
- formProduct: { name, description, price, stock }
- productImage: File

// Methods
- loadProducts()              // GET /api/products
- loadOrders()                // GET /api/orders
- createProduct()             // POST /api/products (con imagen)
- selectProduct(product)      // Selecciona producto para comprar
- createOrder()               // POST /api/orders
- getStatusClass(status)      // Retorna clase CSS para estado
- onImageSelected(event)      // Captura archivo seleccionado
```

### api.js

```javascript
// Funciones disponibles
- api.getProducts()           // GET /api/products
- api.createProduct(product)  // POST /api/products (solo datos)
- api.getOrders()             // GET /api/orders
- api.createOrder(order)      // POST /api/orders
```

## Desarrollo

El frontend es completamente cliente. Para testear localmente:

1. Asegúrate que el backend está corriendo:
   ```bash
   npm run dev
   ```

2. Abre http://localhost:3000 en el navegador

3. Los cambios en `frontend/` se reflejan en tiempo real (no requiere refresh en muchos casos)

## Deployment en AWS

Cuando despliegas con Terraform:

1. EC2 clona el repo
2. Express sirve `frontend/index.html` desde `/`
3. NGINX funciona como reverse proxy
4. Usuarios acceden vía ALB DNS

## Notas

- Las imágenes se cargan con `v-for` en la galería
- El estado de órdenes se actualiza automáticamente
- No hay persistencia en navegador (localStorage)
- Compatible con internet explorer moderno y navegadores actuales

