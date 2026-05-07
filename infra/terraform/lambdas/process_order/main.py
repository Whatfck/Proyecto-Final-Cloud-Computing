import json
import logging
import os
import random

import boto3
import psycopg2

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sns_client = boto3.client("sns")


def _get_db_conn():
    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=int(os.environ.get("DB_PORT", 5432)),
        dbname=os.environ["DB_NAME"],
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        connect_timeout=5,
    )


def _simulate_payment(order_id, total):
    """Simula procesamiento de pago. Falla ~10% de las veces para demostrar DLQ."""
    if random.random() < 0.1:
        raise ValueError(f"Payment gateway rejected order {order_id} (simulated failure)")
    return {
        "transactionId": f"TXN-{order_id}-{random.randint(10000, 99999)}",
        "status": "APPROVED",
        "amount": total,
    }


def _update_order_status(conn, order_id, status):
    with conn.cursor() as cur:
        cur.execute(
            "UPDATE orders SET status = %s WHERE id = %s",
            (status, order_id),
        )
    conn.commit()


def _publish(topic_arn, event_type, payload):
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

    batch_item_failures = []

    for record in event.get("Records", []):
        message_id = record["messageId"]
        body = record.get("body", "{}")
        order = json.loads(body)
        order_id = order.get("orderId", "unknown")

        try:
            logger.info("Processing payment for order %s", order_id)

            # Simular pago
            payment = _simulate_payment(order_id, order.get("total", 0))
            logger.info("Payment approved: %s", payment["transactionId"])

            # Actualizar estado en RDS
            try:
                conn = _get_db_conn()
                _update_order_status(conn, order_id, "PROCESSING")
                conn.close()
            except Exception as db_err:
                logger.warning("Could not update RDS status: %s", db_err)

            # Fan-out: notificar vendedor
            _publish(
                topic_arn,
                "SELLER_NOTIFY",
                {
                    "orderId": order_id,
                    "productId": order.get("productId"),
                    "productName": order.get("productName"),
                    "quantity": order.get("quantity"),
                    "total": order.get("total"),
                    "buyerEmail": order.get("buyerEmail"),
                    "transactionId": payment["transactionId"],
                    "status": "PAYMENT_PROCESSED",
                },
            )

            # Fan-out: actualizar inventario
            _publish(
                topic_arn,
                "INVENTORY_UPDATE",
                {
                    "orderId": order_id,
                    "productId": order.get("productId"),
                    "quantity": order.get("quantity"),
                    "status": "INVENTORY_RESERVE_REQUESTED",
                },
            )

            logger.info("Order %s processed successfully", order_id)

        except Exception as e:
            logger.error("Failed to process order %s: %s", order_id, str(e))
            batch_item_failures.append({"itemIdentifier": message_id})

    return {"batchItemFailures": batch_item_failures}
