variable "aws_region" {
  description = "AWS region for the demo infrastructure"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used to prefix resources"
  type        = string
  default     = "grupo3-marketplace"
}

variable "db_name" {
  description = "Logical database name for the marketplace RDS instance"
  type        = string
  default     = "grupo3_marketplace"
}

variable "db_username" {
  description = "Master username for the marketplace database"
  type        = string
  default     = "grupo3admin"
}

variable "db_password" {
  description = "Master password for the marketplace database"
  type        = string
  default     = "Grupo3Demo2026!"
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class used for the demo"
  type        = string
  default     = "db.t3.micro"
}

variable "db_engine" {
  description = "Database engine for the marketplace demo"
  type        = string
  default     = "postgres"
}

variable "db_engine_version" {
  description = "Database engine version for the marketplace demo"
  type        = string
  default     = ""
}

variable "db_port" {
  description = "Database port for the marketplace demo"
  type        = number
  default     = 5432
}

variable "lambda_runtime" {
  description = "Runtime used by the marketplace Lambdas"
  type        = string
  default     = "python3.11"
}

variable "lambda_timeout" {
  description = "Timeout in seconds for the marketplace Lambdas"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Memory size in MB for the marketplace Lambdas"
  type        = number
  default     = 256
}

variable "ec2_instance_type" {
  description = "EC2 instance type for the web tier"
  type        = string
  default     = "t2.micro"
}

variable "ec2_desired_capacity" {
  description = "Desired number of web EC2 instances"
  type        = number
  default     = 2
}

variable "ec2_min_capacity" {
  description = "Minimum number of web EC2 instances"
  type        = number
  default     = 2
}

variable "ec2_max_capacity" {
  description = "Maximum number of web EC2 instances"
  type        = number
  default     = 3
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "azs" {
  description = "Availability zones to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "aws_access_key_id" {
  description = "AWS Access Key ID for EC2 instances to access S3 and other AWS services"
  type        = string
  default     = ""
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key for EC2 instances to access S3 and other AWS services"
  type        = string
  default     = ""
  sensitive   = true
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default = {
    Project     = "grupo3-marketplace"
    Environment = "demo"
    ManagedBy   = "terraform"
  }
}
