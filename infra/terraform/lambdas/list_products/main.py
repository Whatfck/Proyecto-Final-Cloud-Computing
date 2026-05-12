import json
import logging
import os
import pg8000.native

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def _get_db_conn():
    return pg8000.native.Connection(
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        host=os.environ["DB_HOST"],
        database=os.environ["DB_NAME"],
        port=int(os.environ.get("DB_PORT", 5432))
    )

def handler(event, context):
    try:
        conn = _get_db_conn()
        res = conn.run("SELECT id, name, description, price, stock, image_url FROM products ORDER BY id ASC")
        conn.close()
        
        products = []
        for row in res:
            products.append({
                "id": row[0],
                "name": row[1],
                "description": row[2],
                "price": float(row[3]),
                "stock": row[4],
                "image": row[5]
            })
            
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
            "body": json.dumps(products)
        }
    except Exception as e:
        logger.error(f"Error listing products: {str(e)}")
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"error": str(e)})
        }
