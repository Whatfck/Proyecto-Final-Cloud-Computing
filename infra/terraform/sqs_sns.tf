resource "aws_sqs_queue" "orders_dlq" {
  name = "${var.project_name}-orders-dlq"

  message_retention_seconds = 1209600

  tags = merge(var.tags, {
    Name = "${var.project_name}-orders-dlq"
  })
}

resource "aws_sqs_queue" "orders" {
  name                      = "${var.project_name}-orders"
  receive_wait_time_seconds = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.orders_dlq.arn
    maxReceiveCount     = 3
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-orders"
  })
}

resource "aws_sqs_queue" "seller_notifications" {
  name = "${var.project_name}-seller-notifications"

  tags = merge(var.tags, {
    Name = "${var.project_name}-seller-notifications"
  })
}

resource "aws_sns_topic" "orders_events" {
  name = "${var.project_name}-orders-events"

  tags = merge(var.tags, {
    Name = "${var.project_name}-orders-events"
  })
}

resource "aws_sns_topic" "admin_alerts" {
  name = "${var.project_name}-admin-alerts"

  tags = merge(var.tags, {
    Name = "${var.project_name}-admin-alerts"
  })
}

# Email subscriptions (only if admin_email is provided)
resource "aws_sns_topic_subscription" "orders_email" {
  count     = var.admin_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.orders_events.arn
  protocol  = "email"
  endpoint  = var.admin_email
}

resource "aws_sns_topic_subscription" "admin_alerts_email" {
  count     = var.admin_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.admin_alerts.arn
  protocol  = "email"
  endpoint  = var.admin_email
}

resource "aws_sns_topic_subscription" "payment_processor" {
  topic_arn = aws_sns_topic.orders_events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.orders.arn

  filter_policy = jsonencode({
    eventType = ["ORDER_CREATED", "PAYMENT_REQUESTED"]
  })
}

resource "aws_sns_topic_subscription" "seller_notifier" {
  topic_arn = aws_sns_topic.orders_events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.seller_notifications.arn

  filter_policy = jsonencode({
    eventType = ["ORDER_CREATED"]
  })
}

resource "aws_sqs_queue_policy" "orders_allow_sns" {
  queue_url = aws_sqs_queue.orders.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSNSSendMessage"
        Effect    = "Allow"
        Principal = "*"
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.orders.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.orders_events.arn
          }
        }
      }
    ]
  })
}

resource "aws_sqs_queue_policy" "seller_allow_sns" {
  queue_url = aws_sqs_queue.seller_notifications.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSNSSendMessage"
        Effect    = "Allow"
        Principal = "*"
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.seller_notifications.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.orders_events.arn
          }
        }
      }
    ]
  })
}
