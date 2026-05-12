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
        port=int(os.environ.get("DB_PORT", 5432)),
        timeout=10
    )

def handler(event, context):
    handled = []

    for record in event.get("Records", []):
        sns_message = record.get("Sns", {})
        payload = json.loads(sns_message.get("Message", "{}"))

        order_id = payload.get("orderId", "unknown")
        product_id = payload.get("productId")
        quantity = payload.get("quantity", 0)

        logger.info("Inventory update for order %s: product %s qty %s", order_id, product_id, quantity)

        if not product_id or not quantity:
            logger.warning("Missing productId or quantity in payload, skipping")
            continue

        try:
            conn = _get_db_conn()
            res = conn.run(
                "UPDATE products SET stock = GREATEST(stock - :qty, 0) WHERE id = :id RETURNING stock",
                qty=quantity, id=product_id
            )
            conn.close()
            
            remaining = res[0][0] if res else "unknown"
            logger.info("Stock updated for product %s — remaining: %s", product_id, remaining)
            handled.append(order_id)
        except Exception as e:
            logger.error("Failed to update inventory for order %s: %s", order_id, str(e))
            raise

    return {"statusCode": 200, "handledOrders": handled}
