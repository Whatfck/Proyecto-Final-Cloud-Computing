resource "aws_s3_bucket" "product_images" {
  bucket        = "${var.project_name}-product-images"
  force_destroy = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-product-images"
  })
}

resource "aws_s3_bucket_public_access_block" "product_images" {
  bucket = aws_s3_bucket.product_images.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "product_images" {
  bucket = aws_s3_bucket.product_images.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Bucket para builds compilados del backend
resource "aws_s3_bucket" "builds" {
  bucket        = "${var.project_name}-builds"
  force_destroy = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-builds"
  })
}

resource "aws_s3_bucket_public_access_block" "builds" {
  bucket = aws_s3_bucket.builds.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "builds" {
  bucket = aws_s3_bucket.builds.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_notification" "product_images_validation" {
  bucket = aws_s3_bucket.product_images.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.image_validator.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "products/"
  }

  depends_on = [aws_lambda_permission.s3_invoke_validator]
}
