import json
import logging
import os
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")
rekognition = boto3.client("rekognition")
sns = boto3.client("sns")

def handler(event, context):
    topic_arn = os.environ.get("ADMIN_TOPIC_ARN", "")
    
    for record in event.get("Records", []):
        bucket = record["s3"]["bucket"]["name"]
        key = record["s3"]["object"]["key"]
        
        if not key.startswith("products/"):
            continue
            
        logger.info(f"Validating image: s3://{bucket}/{key}")
        
        try:
            response = rekognition.detect_moderation_labels(
                Image={
                    "S3Object": {
                        "Bucket": bucket,
                        "Name": key
                    }
                }
            )
            
            labels = response.get("ModerationLabels", [])
            if labels:
                logger.warning(f"Explicit content detected in {key}: {labels}")
                reject_image(bucket, key, topic_arn, f"Explicit content detected: {[l['Name'] for l in labels]}")
                continue
                
            head = s3.head_object(Bucket=bucket, Key=key)
            size_mb = head["ContentLength"] / (1024 * 1024)
            if size_mb > 5:
                logger.warning(f"Image too large ({size_mb} MB): {key}")
                reject_image(bucket, key, topic_arn, "Image exceeds 5MB limit")
                continue
                
            logger.info(f"Image {key} passed validation.")
            
        except Exception as e:
            logger.error(f"Error validating {key}: {e}")
            
    return {"statusCode": 200}

def reject_image(bucket, key, topic_arn, reason):
    filename = key.split("/")[-1]
    new_key = f"rejected/{filename}"
    
    s3.copy_object(
        Bucket=bucket,
        CopySource=f"{bucket}/{key}",
        Key=new_key
    )
    s3.delete_object(Bucket=bucket, Key=key)
    logger.info(f"Moved {key} to {new_key}")
    
    if topic_arn:
        sns.publish(
            TopicArn=topic_arn,
            Subject="Marketplace Alert: Image Rejected",
            Message=f"An image was rejected during upload.\nFile: {filename}\nReason: {reason}"
        )
