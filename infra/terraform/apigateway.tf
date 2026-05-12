resource "aws_apigatewayv2_api" "marketplace" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "GET", "OPTIONS"]
    allow_headers = ["content-type"]
    max_age       = 300
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-api"
  })
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.marketplace.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "order_entry" {
  api_id           = aws_apigatewayv2_api.marketplace.id
  integration_type = "AWS_PROXY"

  integration_method     = "POST"
  integration_uri        = aws_lambda_function.order_entry.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "order_entry" {
  api_id    = aws_apigatewayv2_api.marketplace.id
  route_key = "POST /api/orders"
  target    = "integrations/${aws_apigatewayv2_integration.order_entry.id}"
}

resource "aws_apigatewayv2_integration" "list_orders" {
  api_id           = aws_apigatewayv2_api.marketplace.id
  integration_type = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.list_orders.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_orders" {
  api_id    = aws_apigatewayv2_api.marketplace.id
  route_key = "GET /api/orders"
  target    = "integrations/${aws_apigatewayv2_integration.list_orders.id}"
}

resource "aws_apigatewayv2_integration" "list_products" {
  api_id           = aws_apigatewayv2_api.marketplace.id
  integration_type = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.list_products.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "list_products" {
  api_id    = aws_apigatewayv2_api.marketplace.id
  route_key = "GET /api/products"
  target    = "integrations/${aws_apigatewayv2_integration.list_products.id}"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.order_entry.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.marketplace.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gw_list_orders" {
  statement_id  = "AllowExecutionFromAPIGatewayListOrders"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_orders.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.marketplace.execution_arn}/*/*"
}

resource "aws_lambda_permission" "api_gw_list_products" {
  statement_id  = "AllowExecutionFromAPIGatewayListProducts"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_products.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.marketplace.execution_arn}/*/*"
}

output "api_endpoint" {
  description = "HTTP API Gateway endpoint URL"
  value       = aws_apigatewayv2_api.marketplace.api_endpoint
}
