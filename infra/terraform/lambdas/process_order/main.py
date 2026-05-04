import json
import logging
import os

import boto3


logger = logging.getLogger()
logger.setLevel(logging.INFO)

sns_client = boto3.client("sns")


def _publish(topic_arn: str, event_type: str, payload: dict) -> None:
    sns_client.publish(
        TopicArn=topic_arn,
        Message=json.dumps(payload),
        MessageAttributes={
            "eventType": {
                "DataType": "String",
                "StringValue": event_type,
            }
        },
    )


def handler(event, context):
    topic_arn = os.environ["ORDERS_TOPIC_ARN"]
    db_host = os.environ.get("DB_HOST", "")
    db_name = os.environ.get("DB_NAME", "")

    processed_orders = []
    for record in event.get("Records", []):
        body = record.get("body", "{}")
        order = json.loads(body)
        order_id = order.get("orderId", "unknown")

        logger.info("Processing order %s for db=%s host=%s", order_id, db_name, db_host)

        _publish(
            topic_arn,
            "SELLER_NOTIFY",
            {
                "orderId": order_id,
                "status": "PAYMENT_PROCESSED",
                "target": "seller",
            },
        )

        _publish(
            topic_arn,
            "INVENTORY_UPDATE",
            {
                "orderId": order_id,
                "status": "INVENTORY_RESERVE_REQUESTED",
                "target": "inventory",
            },
        )

        processed_orders.append(order_id)

    return {
        "statusCode": 200,
        "processedOrders": processed_orders,
    }