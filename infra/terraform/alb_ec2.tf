data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for the application load balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-alb-sg"
  })
}

resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "Security group for Ubuntu web instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "App port from NGINX proxy (internal)"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "SSH temporal"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-web-sg"
  })
}

resource "aws_lb" "web" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for subnet in aws_subnet.public : subnet.id]

  tags = merge(var.tags, {
    Name = "${var.project_name}-alb"
  })
}

resource "aws_lb_target_group" "web" {
  name        = "${var.project_name}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-tg"
  })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_instance" "canary_app" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.ec2_instance_type
  key_name      = "grupo3-marketplace-key"
  subnet_id     = aws_subnet.public[1].id

  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_marketplace.name

  user_data = base64encode(templatefile("${path.module}/user_data_app.sh", {
    aws_region           = var.aws_region
    aws_access_key_id    = var.aws_access_key_id
    aws_secret_key       = var.aws_secret_access_key
    db_endpoint          = aws_db_instance.marketplace.endpoint
    db_port              = var.db_port
    db_password          = var.db_password
    s3_bucket_name       = aws_s3_bucket.product_images.id
    builds_bucket_name   = aws_s3_bucket.builds.id
    orders_queue_url     = aws_sqs_queue.orders.url
    app_role             = "canary"
  }))

  tags = merge(var.tags, {
    Name = "${var.project_name}-web-canary-app"
  })
}

resource "aws_instance" "main_app" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.ec2_instance_type
  key_name      = "grupo3-marketplace-key"
  subnet_id     = aws_subnet.public[0].id

  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_marketplace.name

  user_data = base64encode(templatefile("${path.module}/user_data_app.sh", {
    aws_region           = var.aws_region
    aws_access_key_id    = var.aws_access_key_id
    aws_secret_key       = var.aws_secret_access_key
    db_endpoint          = aws_db_instance.marketplace.endpoint
    db_port              = var.db_port
    db_password          = var.db_password
    s3_bucket_name       = aws_s3_bucket.product_images.id
    builds_bucket_name   = aws_s3_bucket.builds.id
    orders_queue_url     = aws_sqs_queue.orders.url
    app_role             = "main"
  }))

  tags = merge(var.tags, {
    Name = "${var.project_name}-web-main-app"
  })
}

resource "aws_instance" "nginx_proxy" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.ec2_instance_type
  key_name      = "grupo3-marketplace-key"
  subnet_id     = aws_subnet.public[0].id

  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_marketplace.name

  user_data = base64encode(templatefile("${path.module}/user_data_nginx.sh", {
    main_ip              = aws_instance.main_app.private_ip
    canary_ip            = aws_instance.canary_app.private_ip
  }))

  depends_on = [aws_instance.main_app, aws_instance.canary_app]

  tags = merge(var.tags, {
    Name = "${var.project_name}-web-nginx-proxy"
  })
}

resource "aws_lb_target_group_attachment" "nginx_proxy" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.nginx_proxy.id
  port             = 80
}