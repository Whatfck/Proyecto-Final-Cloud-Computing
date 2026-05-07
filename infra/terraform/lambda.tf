locals {
  lambda_source_dir = "${path.module}/lambdas"
  
  lambda_common_env_vars = {
    DB_HOST          = aws_db_instance.marketplace.address
    DB_PORT          = tostring(aws_db_instance.marketplace.port)
    DB_NAME          = aws_db_instance.marketplace.db_name
    DB_USER          = var.db_username
    DB_PASSWORD      = var.db_password
    ORDERS_TOPIC_ARN = aws_sns_topic.orders_events.arn
    ADMIN_TOPIC_ARN  = aws_sns_topic.admin_alerts.arn
    DLQ_URL          = aws_sqs_queue.orders_dlq.url
  }
}

resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-lambda-sg"
  description = "Security group for marketplace Lambda functions"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-lambda-sg"
  })
}

data "archive_file" "process_order" {
  type        = "zip"
  source_dir  = "${local.lambda_source_dir}/process_order"
  output_path = "${path.module}/build/process_order.zip"
}

data "archive_file" "seller_notifier" {
  type        = "zip"
  source_dir  = "${local.lambda_source_dir}/seller_notifier"
  output_path = "${path.module}/build/seller_notifier.zip"
}

data "archive_file" "inventory_updater" {
  type        = "zip"
  source_dir  = "${local.lambda_source_dir}/inventory_updater"
  output_path = "${path.module}/build/inventory_updater.zip"
}

data "archive_file" "dlq_monitor" {
  type        = "zip"
  source_dir  = "${local.lambda_source_dir}/dlq_monitor"
  output_path = "${path.module}/build/dlq_monitor.zip"
}

data "archive_file" "image_validator" {
  type        = "zip"
  source_dir  = "${local.lambda_source_dir}/image_validator"
  output_path = "${path.module}/build/image_validator.zip"
}

resource "aws_lambda_function" "process_order" {
  function_name    = "${var.project_name}-process-order"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "main.handler"
  runtime          = var.lambda_runtime
  filename         = data.archive_file.process_order.output_path
  source_code_hash = data.archive_file.process_order.output_base64sha256
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  vpc_config {
    subnet_ids         = [for subnet in aws_subnet.private : subnet.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = local.lambda_common_env_vars
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_vpc_access,
    aws_iam_role_policy_attachment.lambda_marketplace_policy
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-process-order"
  })
}

resource "aws_lambda_function" "seller_notifier" {
  function_name    = "${var.project_name}-seller-notifier"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "main.handler"
  runtime          = var.lambda_runtime
  filename         = data.archive_file.seller_notifier.output_path
  source_code_hash = data.archive_file.seller_notifier.output_base64sha256
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  vpc_config {
    subnet_ids         = [for subnet in aws_subnet.private : subnet.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = local.lambda_common_env_vars
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_vpc_access,
    aws_iam_role_policy_attachment.lambda_marketplace_policy
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-seller-notifier"
  })
}

resource "aws_lambda_function" "inventory_updater" {
  function_name    = "${var.project_name}-inventory-updater"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "main.handler"
  runtime          = var.lambda_runtime
  filename         = data.archive_file.inventory_updater.output_path
  source_code_hash = data.archive_file.inventory_updater.output_base64sha256
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  vpc_config {
    subnet_ids         = [for subnet in aws_subnet.private : subnet.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = local.lambda_common_env_vars
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_vpc_access,
    aws_iam_role_policy_attachment.lambda_marketplace_policy
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-inventory-updater"
  })
}

resource "aws_lambda_event_source_mapping" "process_order_orders_queue" {
  event_source_arn                   = aws_sqs_queue.orders.arn
  function_name                      = aws_lambda_function.process_order.arn
  batch_size                         = 10
  enabled                            = true
  function_response_types            = ["ReportBatchItemFailures"]
  maximum_batching_window_in_seconds = 0
}

resource "aws_lambda_event_source_mapping" "seller_notifier_queue" {
  event_source_arn                   = aws_sqs_queue.seller_notifications.arn
  function_name                      = aws_lambda_function.seller_notifier.arn
  batch_size                         = 10
  enabled                            = true
  function_response_types            = ["ReportBatchItemFailures"]
  maximum_batching_window_in_seconds = 0
}

resource "aws_lambda_permission" "inventory_updater_from_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.inventory_updater.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.orders_events.arn
}

resource "aws_sns_topic_subscription" "inventory_updater" {
  topic_arn = aws_sns_topic.orders_events.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.inventory_updater.arn

  filter_policy = jsonencode({
    eventType = ["INVENTORY_UPDATE"]
  })

  depends_on = [aws_lambda_permission.inventory_updater_from_sns]
}

resource "aws_lambda_function" "dlq_monitor" {
  function_name    = "${var.project_name}-dlq-monitor"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "main.handler"
  runtime          = var.lambda_runtime
  filename         = data.archive_file.dlq_monitor.output_path
  source_code_hash = data.archive_file.dlq_monitor.output_base64sha256
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  vpc_config {
    subnet_ids         = [for subnet in aws_subnet.private : subnet.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = local.lambda_common_env_vars
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_vpc_access,
    aws_iam_role_policy_attachment.lambda_marketplace_policy
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-dlq-monitor"
  })
}

resource "aws_lambda_function" "image_validator" {
  function_name    = "${var.project_name}-image-validator"
  role             = aws_iam_role.lambda_execution.arn
  handler          = "main.handler"
  runtime          = var.lambda_runtime
  filename         = data.archive_file.image_validator.output_path
  source_code_hash = data.archive_file.image_validator.output_base64sha256
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  vpc_config {
    subnet_ids         = [for subnet in aws_subnet.private : subnet.id]
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = local.lambda_common_env_vars
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic,
    aws_iam_role_policy_attachment.lambda_vpc_access,
    aws_iam_role_policy_attachment.lambda_marketplace_policy
  ]

  tags = merge(var.tags, {
    Name = "${var.project_name}-image-validator"
  })
}

resource "aws_cloudwatch_event_rule" "every_five_minutes" {
  name                = "${var.project_name}-every-five-minutes"
  description         = "Fires every five minutes"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "trigger_dlq_monitor" {
  rule      = aws_cloudwatch_event_rule.every_five_minutes.name
  target_id = "dlq_monitor"
  arn       = aws_lambda_function.dlq_monitor.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_dlq_monitor" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.dlq_monitor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.every_five_minutes.arn
}

resource "aws_lambda_permission" "s3_invoke_validator" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.image_validator.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.product_images.arn
}