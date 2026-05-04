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
