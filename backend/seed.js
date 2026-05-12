const { Client } = require('pg');

const client = new Client({
  host: 'grupo3-marketplace-db.caj8o0miwa3g.us-east-1.rds.amazonaws.com',
  user: 'grupo3admin',
  password: 'Grupo3Demo2026!',
  database: 'grupo3_marketplace',
  port: 5432,
  ssl: { rejectUnauthorized: false },
});

const products = [
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

async function seed() {
  try {
    await client.connect();
    console.log('Connected to DB');
    
    // Truncate tables to ensure ONLY these 15 exist
    await client.query('TRUNCATE products, orders RESTART IDENTITY');
    console.log('Tables truncated');
    
    // Insert products
    for (const p of products) {
      await client.query(
        'INSERT INTO products (name, description, price, stock) VALUES ($1, $2, $3, $4)',
        [p.name, p.desc, p.price, p.stock]
      );
    }
    console.log('Inserted 15 products successfully.');
    
  } catch (err) {
    console.error('Error seeding DB:', err);
  } finally {
    await client.end();
  }
}

seed();
