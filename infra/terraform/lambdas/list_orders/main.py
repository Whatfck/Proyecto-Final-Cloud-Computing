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
        res = conn.run("SELECT id, product_id, product_name, quantity, total, status, created_at FROM orders ORDER BY id DESC LIMIT 50")
        conn.close()
        
        orders = []
        for row in res:
            orders.append({
                "id": row[0],
                "productId": row[1],
                "productName": row[2],
                "quantity": row[3],
                "total": float(row[4]),
                "status": row[5],
                "createdAt": row[6].isoformat() if row[6] else None
            })
            
        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
            "body": json.dumps(orders)
        }
    except Exception as e:
        logger.error(f"Error listing orders: {str(e)}")
        return {
            "statusCode": 500,
            "headers": {"Content-Type": "application/json", "Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"error": str(e)})
        }
