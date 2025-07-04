terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.AWS_REGION
}

resource "aws_key_pair" "ec2_key" {
  key_name   = "ec2_key"
  public_key = file("~/.ssh/ec2_key.pub")
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2_security_group_v2"
  description = "Allow SSH and HTTP traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8031
    to_port     = 8031
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8032
    to_port     = 8032
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8033
    to_port     = 8033
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 4334
    to_port     = 4334
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 4335
    to_port     = 4335
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 4336
    to_port     = 4336
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8998
    to_port     = 8998
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8084
    to_port     = 8084
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9004
    to_port     = 9004
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 7888
    to_port     = 7888
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "marketplace_server" {
  ami                         = "ami-017095afb82994ac7"
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  key_name                    = aws_key_pair.ec2_key.key_name
  security_groups             = [aws_security_group.ec2_sg.name]
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]

  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name
  user_data_replace_on_change = true

  user_data = <<-EOF
              #!/bin/bash
              set -ex
              # Install and start Docker
              sudo yum install -y docker
              sudo systemctl start docker
              sudo systemctl enable docker
              sudo usermod -aG docker ec2-user
              EOF

  tags = {
    Name = "MarketplaceServer"
  }
}

resource "random_string" "bucket_id" {
  length  = 8
  special = false
  upper   = false
}

resource "aws_s3_bucket" "marketplace_bucket" {
  bucket = "marketplace-bucket-${random_string.bucket_id.result}"

  tags = {
    Name        = "MarketplaceBucket"
    Environment = "Prod"
  }
}

resource "aws_s3_bucket_cors_configuration" "marketplace_bucket_cors" {
  bucket = aws_s3_bucket.marketplace_bucket.id

  cors_rule {
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
  }
}

resource "aws_s3_bucket_public_access_block" "frontend_bucket_public_access" {
  bucket                  = aws_s3_bucket.marketplace_bucket.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "frontend_bucket_policy" {
  bucket = aws_s3_bucket.marketplace_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.marketplace_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_s3_object" "test_image" {
  bucket       = aws_s3_bucket.marketplace_bucket.id
  key          = "example.png"
  source       = "${path.module}/example.png"
  content_type = "image/png"
}

resource "aws_iam_role" "ec2_s3_role" {
  name = "ec2-s3-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "ec2_s3_dynamodb_access_policy" {
  name        = "ec2-s3-dynamodb-access-policy"
  description = "Allows EC2 instances to access S3 bucket and DynamoDB table"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = ["s3:ListBucket", "s3:GetObject", "s3:PutObject"],
        Resource = [
          aws_s3_bucket.marketplace_bucket.arn,
          "${aws_s3_bucket.marketplace_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "dynamodb:CreateTable",
          "dynamodb:DescribeTable",
          "dynamodb:DeleteItem",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:UpdateItem"
        ],
        Resource = aws_dynamodb_table.datomic_tx.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_s3_policy_attachment" {
  role       = aws_iam_role.ec2_s3_role.name
  policy_arn = aws_iam_policy.ec2_s3_dynamodb_access_policy.arn
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2-s3-instance-profile"
  role = aws_iam_role.ec2_s3_role.name
}

resource "aws_dynamodb_table" "datomic_tx" {
  name           = "datomic-tx"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_db_instance" "postgres_db" {
  allocated_storage      = 20
  max_allocated_storage  = 100
  identifier             = "postgres-instance"
  engine                 = "postgres"
  engine_version         = "16.4"
  instance_class         = "db.t4g.micro"
  db_name                = var.POSTGRES_DB_NAME
  username               = var.POSTGRES_USERNAME
  password               = var.POSTGRES_PASSWORD
  publicly_accessible    = true
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  tags = {
    Name = "PostgresDB"
  }
}

output "marketplace_bucket_url" {
  value       = "http://${aws_s3_bucket.marketplace_bucket.bucket}.s3.amazonaws.com/"
  description = "The URL of the S3 bucket"
}

output "marketplace_server_public_ip" {
  value       = aws_instance.marketplace_server.public_ip
  description = "Public IP address of the Marketplace EC2 server"
}

output "postgres_db_endpoint" {
  value       = aws_db_instance.postgres_db.endpoint
  description = "The endpoint of the Postgres DB instance"
}
