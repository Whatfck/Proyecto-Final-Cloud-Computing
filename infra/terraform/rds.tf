resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "Security group for the marketplace database"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from Lambda"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  ingress {
    description     = "MySQL from internal services"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.internal.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-db-sg"
  })
}

resource "aws_db_subnet_group" "marketplace" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [for subnet in aws_subnet.private : subnet.id]

  tags = merge(var.tags, {
    Name = "${var.project_name}-db-subnet-group"
  })
}

resource "aws_db_instance" "marketplace" {
  identifier = "${var.project_name}-db"

  allocated_storage       = 20
  storage_type            = "gp2"
  engine                  = var.db_engine
  engine_version          = var.db_engine_version
  instance_class          = var.db_instance_class
  db_name                 = var.db_name
  username                = var.db_username
  password                = var.db_password
  port                    = 3306
  publicly_accessible     = false
  multi_az                = false
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true
  backup_retention_period = 0

  db_subnet_group_name   = aws_db_subnet_group.marketplace.name
  vpc_security_group_ids = [aws_security_group.db.id]

  tags = merge(var.tags, {
    Name = "${var.project_name}-db"
  })
}