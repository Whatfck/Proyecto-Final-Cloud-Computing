import json
import logging
import os

import psycopg2

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def _get_db_conn():
    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=int(os.environ.get("DB_PORT", 5432)),
        dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        connect_timeout=5,
    )


def _decrement_stock(conn, product_id, quantity):
    with conn.cursor() as cur:
        cur.execute(
            """
            UPDATE products
            SET stock = GREATEST(stock - %s, 0)
            WHERE id = %s
            RETURNING stock
            """,
            (quantity, product_id),
        )
        row = cur.fetchone()
    conn.commit()
    return row[0] if row else None


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
            remaining = _decrement_stock(conn, product_id, quantity)
            conn.close()
            logger.info("Stock updated for product %s — remaining: %s", product_id, remaining)
            handled.append(order_id)
        except Exception as e:
            logger.error("Failed to update inventory for order %s: %s", order_id, str(e))
            raise

    return {"statusCode": 200, "handledOrders": handled}
