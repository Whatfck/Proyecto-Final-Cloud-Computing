import json
import logging
import os


logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    db_host = os.environ.get("DB_HOST", "")
    db_name = os.environ.get("DB_NAME", "")
    processed_messages = []

    for record in event.get("Records", []):
        body = record.get("body", "{}")
        payload = json.loads(body)
        order_id = payload.get("orderId", "unknown")
        logger.info("Seller notification for order %s on db=%s/%s", order_id, db_host, db_name)
        processed_messages.append(order_id)

    return {
        "statusCode": 200,
        "processedMessages": processed_messages,
    }