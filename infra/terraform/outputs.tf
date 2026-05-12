output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "public_security_group_id" {
  description = "Security group for public EC2 instances"
  value       = aws_security_group.ec2_public.id
}

output "internal_security_group_id" {
  description = "Security group for internal services"
  value       = aws_security_group.internal.id
}

output "product_images_bucket_name" {
  description = "S3 bucket name for product images"
  value       = aws_s3_bucket.product_images.bucket
}

output "builds_bucket_name" {
  description = "S3 bucket name for compiled builds"
  value       = aws_s3_bucket.builds.bucket
}

output "orders_queue_url" {
  description = "Main orders SQS queue URL"
  value       = aws_sqs_queue.orders.id
}

output "orders_dlq_url" {
  description = "Dead letter queue URL for failed orders"
  value       = aws_sqs_queue.orders_dlq.id
}

output "orders_events_topic_arn" {
  description = "SNS topic ARN for order events"
  value       = aws_sns_topic.orders_events.arn
}

output "admin_alerts_topic_arn" {
  description = "SNS topic ARN for admin alerts"
  value       = aws_sns_topic.admin_alerts.arn
}

output "lambda_execution_role_arn" {
  description = "IAM role ARN for Lambda execution"
  value       = aws_iam_role.lambda_execution.arn
}

output "marketplace_db_endpoint" {
  description = "RDS endpoint for the marketplace database"
  value       = aws_db_instance.marketplace.address
}

output "marketplace_db_name" {
  description = "Logical database name for the marketplace"
  value       = aws_db_instance.marketplace.db_name
}

output "process_order_lambda_arn" {
  description = "Lambda ARN for order processing"
  value       = aws_lambda_function.process_order.arn
}

output "seller_notifier_lambda_arn" {
  description = "Lambda ARN for seller notifications"
  value       = aws_lambda_function.seller_notifier.arn
}

output "inventory_updater_lambda_arn" {
  description = "Lambda ARN for inventory updates"
  value       = aws_lambda_function.inventory_updater.arn
}

output "lambda_security_group_id" {
  description = "Security group for Lambda functions"
  value       = aws_security_group.lambda.id
}

output "db_security_group_id" {
  description = "Security group for the database"
  value       = aws_security_group.db.id
}

output "alb_dns_name" {
  description = "DNS name of the application load balancer"
  value       = aws_lb.web.dns_name
}

output "alb_arn" {
  description = "ARN of the application load balancer"
  value       = aws_lb.web.arn
}

output "web_target_group_arn" {
  description = "ARN of the web target group"
  value       = aws_lb_target_group.web.arn
}

output "web_main_instance_id" {
  description = "The ID of the main web EC2 instance"
  value       = aws_instance.main_app.id
}

output "web_canary_instance_id" {
  description = "The ID of the canary web EC2 instance"
  value       = aws_instance.canary_app.id
}

output "web_nginx_proxy_id" {
  description = "The ID of the NGINX proxy EC2 instance"
  value       = aws_instance.nginx_proxy.id
}

output "web_instance_security_group_id" {
  description = "Security group for the web EC2 instances"
  value       = aws_security_group.web.id
}

output "alb_security_group_id" {
  description = "Security group for the load balancer"
  value       = aws_security_group.alb.id
}
