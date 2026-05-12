const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const AWS = require('aws-sdk');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');

require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

// Servir archivos estáticos del frontend
app.use(express.static(path.join(__dirname, '../frontend')));

// Configurar multer para uploads en memoria
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
  fileFilter: (req, file, cb) => {
    const allowedMimes = ['image/jpeg', 'image/png', 'image/gif'];
    if (allowedMimes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Solo se permiten imágenes (JPG, PNG, GIF)'));
    }
  },
});

// Variables globales
let products = [];
let orders = [];
let dbConnection = null;
const s3BucketName = process.env.S3_BUCKET_NAME || 'grupo3-marketplace-product-images';
const sqsQueueUrl = process.env.ORDERS_QUEUE_URL;

// Configuración AWS
const s3 = new AWS.S3({
  region: process.env.AWS_REGION || 'us-east-1',
});

const sqs = new AWS.SQS({
  region: process.env.AWS_REGION || 'us-east-1',
});

// Configuración RDS
const rawHost = process.env.DB_HOST || 'localhost';
const dbConfig = {
  host: rawHost.split(':')[0],
  user: process.env.DB_USER || 'admin',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'marketplace',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  ssl: { rejectUnauthorized: false },
  max: 10,
};

let pool;

async function initDB() {
  try {
    pool = new Pool(dbConfig);
    dbConnection = await pool.connect();
    console.log('✅ Conectado a RDS PostgreSQL');
    
    await pool.query(`
      CREATE TABLE IF NOT EXISTS products (
        id SERIAL PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        description TEXT,
        price DECIMAL(10, 2) NOT NULL,
        stock INT NOT NULL,
        image_url VARCHAR(500),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    
    await pool.query(`
      CREATE TABLE IF NOT EXISTS orders (
        id SERIAL PRIMARY KEY,
        product_id INT NOT NULL,
        product_name VARCHAR(255) NOT NULL,
        quantity INT NOT NULL,
        total DECIMAL(10, 2) NOT NULL,
        buyer_name VARCHAR(255) NOT NULL,
        buyer_email VARCHAR(255) NOT NULL,
        status VARCHAR(50) DEFAULT 'PENDING',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    
    // Check if products exist, otherwise seed
    const productsCount = await pool.query('SELECT COUNT(*) FROM products');
    if (parseInt(productsCount.rows[0].count) === 0) {
      console.log('Seeding 15 initial products...');
      const initialProducts = [
        { name: 'Laptop Lenovo IdeaPad 3', desc: 'Laptop para estudio y trabajo', price: 650, stock: 8 },
        { name: 'Mouse Logitech M170', desc: 'Mouse inalámbrico compacto', price: 18, stock: 25 },
        { name: 'Teclado Mecánico Redragon Kumara', desc: 'Teclado gamer RGB', price: 55, stock: 12 },
        { name: 'Monitor Samsung 24"', desc: 'Monitor Full HD IPS', price: 180, stock: 6 },
        { name: 'Audífonos HyperX Cloud Stinger', desc: 'Audífonos para gaming y llamadas', price: 60, stock: 14 },
        { name: 'SSD Kingston 1TB', desc: 'Unidad sólida SATA', price: 75, stock: 10 },
        { name: 'Silla Gamer Cougar Armor', desc: 'Silla ergonómica reclinable', price: 240, stock: 3 },
        { name: 'Control Xbox Series', desc: 'Control inalámbrico original', price: 65, stock: 7 },
        { name: 'Mousepad XL RGB', desc: 'Superficie extendida para gaming', price: 22, stock: 15 },
        { name: 'Webcam Logitech C920', desc: 'Cámara Full HD para streaming', price: 85, stock: 5 },
        { name: 'Escritorio Minimalista', desc: 'Escritorio de madera 120cm', price: 140, stock: 4 },
        { name: 'Lámpara LED Inteligente', desc: 'Luz ajustable con app móvil', price: 35, stock: 11 },
        { name: 'Silla de Oficina Ergonómica', desc: 'Soporte lumbar ajustable', price: 190, stock: 2 },
        { name: 'Organizador de Cables', desc: 'Kit organizador para escritorio', price: 12, stock: 30 },
        { name: 'Cargador USB-C 30W', desc: 'Carga rápida compatible', price: 20, stock: 20 }
      ];
      for (const p of initialProducts) {
        await pool.query(
          'INSERT INTO products (name, description, price, stock) VALUES ($1, $2, $3, $4)',
          [p.name, p.desc, p.price, p.stock]
        );
      }
    }

    // Add random placeholder images to products without images
    await pool.query("UPDATE products SET image_url = 'https://picsum.photos/seed/' || id || '/300/200' WHERE image_url IS NULL");

    const productsResult = await pool.query('SELECT * FROM products ORDER BY id ASC');
    const ordersResult = await pool.query('SELECT * FROM orders ORDER BY id ASC');
    products = productsResult.rows.map((row) => ({
      ...row,
      price: parseFloat(row.price),
      stock: parseInt(row.stock, 10),
      imageUrl: row.image_url,
    }));
    orders = ordersResult.rows.map((row) => ({
      ...row,
      quantity: parseInt(row.quantity, 10),
      total: parseFloat(row.total),
      productName: row.product_name,
    }));
    console.log(`✅ Cargados ${products.length} productos y ${orders.length} órdenes`);
    
    if (dbConnection) dbConnection.release();
  } catch (error) {
    if (dbConnection) dbConnection.release();
    pool = null;
    dbConnection = null;
    console.warn('⚠️  RDS no disponible, usando datos en memoria:', error.message);
    products = [];
  }
}

// Función para subir a S3
async function uploadToS3(file, key) {
  try {
    const params = {
      Bucket: s3BucketName,
      Key: key,
      Body: file.buffer,
      ContentType: file.mimetype,
    };
    
    const result = await s3.upload(params).promise();
    console.log('✅ Archivo subido a S3:', result.Location);
    return result.Location;
  } catch (error) {
    console.error('Error subiendo a S3:', error.message);
    return null;
  }
}

// Función para enviar orden a SQS
async function sendOrderToSQS(order) {
  if (!sqsQueueUrl) {
    console.warn('⚠️  SQS_QUEUE_URL no configurado, saltando envío a SQS');
    return;
  }
  
  try {
    const params = {
      QueueUrl: sqsQueueUrl,
      MessageBody: JSON.stringify({
        orderId: order.id,
        productId: order.product_id,
        productName: order.product_name,
        quantity: order.quantity,
        total: order.total,
        buyerEmail: order.buyer_email,
        status: 'PENDING',
        timestamp: new Date().toISOString(),
      }),
    };
    
    await sqs.sendMessage(params).promise();
    console.log('✅ Orden enviada a SQS:', order.id);
  } catch (error) {
    console.error('Error enviando a SQS:', error.message);
  }
}

// Rutas API
app.get('/api/products', async (req, res) => {
  if (pool) {
    try {
      const result = await pool.query('SELECT * FROM products ORDER BY id ASC');
      const dbProducts = result.rows.map((row) => ({
        ...row,
        price: parseFloat(row.price),
        stock: parseInt(row.stock, 10),
        imageUrl: row.image_url,
      }));
      return res.json(dbProducts);
    } catch (error) {
      console.warn('Error fetching products from DB, falling back to memory:', error.message);
    }
  }
  res.json(products);
});

app.post('/api/products', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'La foto del producto es obligatoria.' });
    }
    const { name, description, price, stock } = req.body;
    
    let imageUrl = null;
    if (req.file) {
      const key = `products/${uuidv4()}-${req.file.originalname}`;
      imageUrl = await uploadToS3(req.file, key);
    }
    
    const newProduct = {
      id: products.length + 1,
      name,
      description,
      price: parseFloat(price),
      stock: parseInt(stock),
      image_url: imageUrl,
      imageUrl: imageUrl,
      created_at: new Date(),
    };
    
    if (pool) {
      try {
        const result = await pool.query(
          'INSERT INTO products (name, description, price, stock, image_url) VALUES ($1, $2, $3, $4, $5) RETURNING id, created_at',
          [name, description, price, stock, imageUrl]
        );
        newProduct.id = result.rows[0].id;
        newProduct.created_at = result.rows[0].created_at;
      } catch (dbError) {
        console.warn('Error insertando en RDS:', dbError.message);
      }
    }
    
    products.push(newProduct);
    res.json({ success: true, product: newProduct });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/orders', async (req, res) => {
  if (pool) {
    try {
      const result = await pool.query('SELECT * FROM orders ORDER BY id ASC');
      const dbOrders = result.rows.map((row) => ({
        ...row,
        quantity: parseInt(row.quantity, 10),
        total: parseFloat(row.total),
        productName: row.product_name,
      }));
      return res.json(dbOrders);
    } catch (error) {
      console.warn('Error fetching orders from DB, falling back to memory:', error.message);
    }
  }
  res.json(orders);
});

app.post('/api/orders', async (req, res) => {
  try {
    const {
      productId,
      productName,
      quantity,
      total,
      buyerName,
      buyerEmail,
    } = req.body;
    
    // Validar stock
    const product = products.find(p => p.id === productId);
    if (!product || product.stock < quantity) {
      return res.status(400).json({ error: 'Stock insuficiente' });
    }
    
    // Actualizar stock
    product.stock -= quantity;
    
    // Crear orden
    const newOrder = {
      id: orders.length + 1,
      product_id: productId,
      product_name: productName,
      productName: productName,
      quantity,
      total,
      buyer_name: buyerName,
      buyer_email: buyerEmail,
      status: 'PENDING',
      created_at: new Date(),
    };
    
    if (pool) {
      try {
        // Insertar orden
        const orderResult = await pool.query(
          'INSERT INTO orders (product_id, product_name, quantity, total, buyer_name, buyer_email, status) VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING id, created_at',
          [productId, productName, quantity, total, buyerName, buyerEmail, 'PENDING']
        );
        
        // Actualizar stock
        await pool.query(
          'UPDATE products SET stock = stock - $1 WHERE id = $2',
          [quantity, productId]
        );

        newOrder.id = orderResult.rows[0].id;
        newOrder.created_at = orderResult.rows[0].created_at;
      } catch (dbError) {
        console.warn('Error insertando en RDS:', dbError.message);
      }
    }
    
    orders.push(newOrder);
    
    // Enviar a SQS
    await sendOrderToSQS(newOrder);
    
    res.json({ success: true, order: newOrder });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// Ruta raíz redirect a index.html
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, '../frontend/index.html'));
});

// Service info (Main vs Canary)
app.get('/api/service-info', (req, res) => {
  const role = process.env.APP_ROLE || 'unknown';
  res.json({
    service: role,
    port: process.env.PORT || 3000,
    instanceId: process.env.HOSTNAME || require('os').hostname()
  });
});

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    timestamp: new Date(),
    database: pool ? 'connected' : 'disconnected',
    s3BucketName,
    sqsQueueUrl: sqsQueueUrl ? 'configured' : 'not configured',
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Error:', err.message);
  res.status(500).json({ error: err.message });
});

// Iniciar servidor
const PORT = process.env.PORT || 3000;
initDB().then(() => {
  app.listen(PORT, () => {
    console.log(`🚀 Backend corriendo en http://localhost:${PORT}`);
    console.log(`📝 Endpoints: /api/products, /api/orders, /health`);
  });
});
