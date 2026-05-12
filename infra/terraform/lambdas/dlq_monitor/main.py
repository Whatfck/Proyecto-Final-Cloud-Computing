import json
import logging
import os
from datetime import datetime

import boto3
import pg8000.native

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sns_client = boto3.client("sns")
sqs_client = boto3.client("sqs")

def _get_db_conn():
    return pg8000.native.Connection(
        user=os.environ["DB_USER"],
        password=os.environ["DB_PASSWORD"],
        host=os.environ["DB_HOST"],
        database=os.environ["DB_NAME"],
        port=int(os.environ.get("DB_PORT", 5432)),
        timeout=10
    )

def _ensure_error_log_table(conn):
    conn.run("""
        CREATE TABLE IF NOT EXISTS failed_orders (
            id SERIAL PRIMARY KEY,
            order_id VARCHAR(255),
            error_body TEXT,
            recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)

def handler(event, context):
    topic_arn = os.environ.get("ADMIN_TOPIC_ARN", "")
    dlq_url = os.environ.get("DLQ_URL", "")

    if not dlq_url:
        logger.warning("DLQ_URL not set")
        return {"statusCode": 400}

    response = sqs_client.receive_message(
        QueueUrl=dlq_url,
        MaxNumberOfMessages=10,
        WaitTimeSeconds=5,
    )

    messages = response.get("Messages", [])
    if not messages:
        logger.info("No messages in DLQ.")
        return {"statusCode": 200, "processed": 0}

    logger.info("Found %d messages in DLQ.", len(messages))

    conn = None
    try:
        conn = _get_db_conn()
        _ensure_error_log_table(conn)
    except Exception as db_err:
        logger.warning("Could not connect to RDS, errors will only be logged: %s", db_err)

    for msg in messages:
        body = msg.get("Body", "{}")
        receipt_handle = msg.get("ReceiptHandle")

        try:
            payload = json.loads(body)
        except json.JSONDecodeError:
            payload = {}

        order_id = payload.get("orderId", "unknown")
        logger.error("Failed order in DLQ — orderId: %s | body: %s", order_id, body)

        # Registrar en RDS
        if conn:
            try:
                conn.run(
                    "INSERT INTO failed_orders (order_id, error_body, recorded_at) VALUES (:oid, :body, :ts)",
                    oid=str(order_id), body=body, ts=datetime.utcnow()
                )
                logger.info("Error logged to RDS for order %s", order_id)
            except Exception as e:
                logger.error("Could not log to RDS: %s", e)

        # Notificar al administrador por SNS
        if topic_arn:
            try:
                sns_client.publish(
                    TopicArn=topic_arn,
                    Subject=f"Marketplace Alert: Orden fallida #{order_id}",
                    Message=(
                        f"Una orden no pudo procesarse después de 3 intentos.\n\n"
                        f"Orden ID: {order_id}\n"
                        f"Detalles:\n{body}"
                    ),
                )
            except Exception as e:
                logger.error("Could not send SNS alert: %s", e)

        # Eliminar de la DLQ después de procesar
        sqs_client.delete_message(QueueUrl=dlq_url, ReceiptHandle=receipt_handle)

    if conn:
        conn.close()

    return {"statusCode": 200, "processed": len(messages)}
