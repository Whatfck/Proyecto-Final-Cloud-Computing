import json
import logging
import os

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sns_client = boto3.client("sns")


def handler(event, context):
    admin_topic_arn = os.environ.get("ADMIN_TOPIC_ARN", "")
    processed = []

    for record in event.get("Records", []):
        body = record.get("body", "{}")
        try:
            sns_msg = json.loads(body)
            if "Message" in sns_msg:
                payload = json.loads(sns_msg["Message"])
            else:
                payload = sns_msg
        except:
            payload = json.loads(body)

        order_id = payload.get("orderId", "unknown")
        product_name = payload.get("productName", "N/A")
        quantity = payload.get("quantity", 0)
        total = payload.get("total", 0)
        buyer_email = payload.get("buyerEmail", "N/A")
        transaction_id = payload.get("transactionId", "N/A")

        logger.info("Sending seller notification for order %s", order_id)

        message = (
            f"Nueva orden recibida!\n\n"
            f"Orden ID: {order_id}\n"
            f"Producto: {product_name}\n"
            f"Cantidad: {quantity}\n"
            f"Total: ${total}\n"
            f"Comprador: {buyer_email}\n"
            f"Transacción: {transaction_id}\n"
        )

        if admin_topic_arn:
            try:
                sns_client.publish(
                    TopicArn=admin_topic_arn,
                    Subject=f"Marketplace: Nueva orden #{order_id}",
                    Message=message,
                )
                logger.info("Seller notification sent for order %s", order_id)
            except Exception as e:
                logger.error("Failed to send notification for order %s: %s", order_id, str(e))
                raise
        else:
            logger.warning("ADMIN_TOPIC_ARN not set, notification not sent")

        processed.append(order_id)

    return {"statusCode": 200, "processedMessages": processed}
