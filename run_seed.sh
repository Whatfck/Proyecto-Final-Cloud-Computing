#!/bin/bash
ASG_NAME=$(cd infra/terraform && terraform output -raw web_autoscaling_group_name)
INSTANCE_ID=$(aws ec2 describe-instances --region us-east-1 --filters "Name=tag:aws:autoscaling:groupName,Values=$ASG_NAME" "Name=instance-state-name,Values=running" --query "Reservations[0].Instances[0].InstanceId" --output text)
echo "Target Instance: $INSTANCE_ID"

cat << 'SCRIPT' > remote_seed.js
const { Client } = require('pg');
const client = new Client({
  host: 'grupo3-marketplace-db.caj8o0miwa3g.us-east-1.rds.amazonaws.com',
  user: 'grupo3admin',
  password: 'Grupo3Demo2026!',
  database: 'grupo3_marketplace',
  port: 5432,
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
    await client.query('TRUNCATE products, orders RESTART IDENTITY');
    for (const p of products) {
      await client.query(
        'INSERT INTO products (name, description, price, stock) VALUES ($1, $2, $3, $4)',
        [p.name, p.desc, p.price, p.stock]
      );
    }
    console.log('Seed success');
  } catch(e) { console.error(e); } finally { await client.end(); }
}
seed();
SCRIPT

CMD_ID=$(aws ssm send-command \
    --region us-east-1 \
    --document-name "AWS-RunShellScript" \
    --targets "Key=instanceids,Values=$INSTANCE_ID" \
    --parameters "commands=[\"cd /home/ubuntu/app/backend || cd /tmp\",\"cat << 'INNEREOF' > seed_ssm.js\",\"$(cat remote_seed.js)\",\"INNEREOF\",\"npm install pg\",\"node seed_ssm.js\",\"sudo systemctl restart marketplace-main marketplace-canary\"]" \
    --query "Command.CommandId" \
    --output text)

echo "Sent command $CMD_ID. Waiting for output..."
sleep 5
aws ssm get-command-invocation --region us-east-1 --command-id "$CMD_ID" --instance-id "$INSTANCE_ID" --query "StandardOutputContent" --output text
