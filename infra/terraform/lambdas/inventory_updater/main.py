import json
import logging
import os


logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    db_host = os.environ.get("DB_HOST", "")
    db_name = os.environ.get("DB_NAME", "")
    event_types = []

    for record in event.get("Records", []):
        sns_message = record.get("Sns", {})
        message = sns_message.get("Message", "{}")
        payload = json.loads(message)
        order_id = payload.get("orderId", "unknown")
        logger.info("Inventory update for order %s on db=%s/%s", order_id, db_host, db_name)
        event_types.append(payload.get("status", "unknown"))

    return {
        "statusCode": 200,
        "handledEventTypes": event_types,
    }