import json
import logging
import os
import uuid
from datetime import datetime

import boto3
import pg8000.native

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sns_client = boto3.client("sns")

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
    topic_arn = os.environ["ORDERS_TOPIC_ARN"]
    
    try:
        # Handle both direct invocation and API Gateway proxy
        body = event.get("body", "{}")
        if isinstance(body, str):
            data = json.loads(body)
        else:
            data = body
            
        product_id = data.get("productId")
        product_name = data.get("productName", "Unknown Product")
        quantity = int(data.get("quantity", 1))
        total = float(data.get("total", 0))
        buyer_name = data.get("buyerName", "Guest")
        buyer_email = data.get("buyerEmail", "guest@example.com")
        
        # 1. Save to RDS (Status: PENDING)
        logger.info("Connecting to DB...")
        conn = _get_db_conn()
        logger.info("Saving order to DB...")
        res = conn.run(
            "INSERT INTO orders (product_id, product_name, quantity, total, buyer_name, buyer_email, status, created_at) "
            "VALUES (:p1, :p2, :p3, :p4, :p5, :p6, :p7, :p8) RETURNING id",
            p1=product_id, p2=product_name, p3=quantity, p4=total, p5=buyer_name, p6=buyer_email, p7="PENDING", p8=datetime.utcnow()
        )
        order_id = res[0][0]
        conn.close()
        
        logger.info(f"Order {order_id} saved to DB. Publishing to SNS...")
        
        # 2. Publish to SNS for Fan-out
        message = {
            "orderId": order_id,
            "productId": product_id,
            "productName": product_name,
            "quantity": quantity,
            "total": total,
            "buyerEmail": buyer_email,
            "buyerName": buyer_name,
            "status": "PENDING"
        }
        
        sns_client.publish(
            TopicArn=topic_arn,
            Message=json.dumps(message),
            MessageAttributes={
                "eventType": {
                    "DataType": "String",
                    "StringValue": "ORDER_CREATED"
                }
            }
        )
        
        logger.info(f"Order {order_id} published to SNS")
        
        return {
            "statusCode": 201,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            },
            "body": json.dumps({
                "message": "Order created successfully",
                "orderId": order_id
            })
        }
        
    except Exception as e:
        logger.error(f"Error creating order: {str(e)}")
        return {
            "statusCode": 500,
            "headers": {
                "Content-Type": "application/json",
                "Access-Control-Allow-Origin": "*"
            },
            "body": json.dumps({"error": str(e)})
        }
