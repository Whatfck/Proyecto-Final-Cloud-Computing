import json
import logging
import os
import random

import boto3
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

def _simulate_payment(order_id, total):
    """Simula procesamiento de pago. Falla ~10% de las veces para demostrar DLQ."""
    if random.random() < 0.1:
        raise ValueError(f"Payment gateway rejected order {order_id} (simulated failure)")
    return {
        "transactionId": f"TXN-{order_id}-{random.randint(10000, 99999)}",
        "status": "APPROVED",
        "amount": total,
    }

def handler(event, context):
    batch_item_failures = []

    for record in event.get("Records", []):
        message_id = record["messageId"]
        body = record.get("body", "{}")
        
        try:
            sns_body = json.loads(body)
            if "Message" in sns_body:
                order = json.loads(sns_body["Message"])
            else:
                order = sns_body
        except:
            order = json.loads(body)
            
        order_id = order.get("orderId", "unknown")

        try:
            logger.info("Processing payment for order %s", order_id)

            # Simular pago
            payment = _simulate_payment(order_id, order.get("total", 0))
            logger.info("Payment approved: %s", payment["transactionId"])

            # Actualizar estado en RDS
            conn = _get_db_conn()
            conn.run(
                "UPDATE orders SET status = :status WHERE id = :id",
                status="COMPLETED", id=order_id
            )
            conn.close()

            logger.info("Order %s completed successfully", order_id)

        except Exception as e:
            logger.error("Failed to process order %s: %s", order_id, str(e))
            batch_item_failures.append({"itemIdentifier": message_id})

    return {"batchItemFailures": batch_item_failures}
