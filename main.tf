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
  region = "eu-central-1"
}

locals {

  postgres_name          = var.POSTGRES_DB_NAME
  postgres_user_name     = var.POSTGRES_USERNAME
  postgres_user_password = var.POSTGRES_PASSWORD

}

resource "aws_key_pair" "ec2_key" {
  key_name   = "ec2_key"
  public_key = file("~/.ssh/ec2_key.pub")
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2_security_group"
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
    from_port   = 5432
    to_port     = 5432
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

  tags = {
    Name = "MarketplaceServer"
  }
}

resource "aws_db_instance" "postgres_db" {
  allocated_storage      = 20
  max_allocated_storage  = 100
  identifier             = "postgres-instance"
  engine                 = "postgres"
  engine_version         = "16.1"
  instance_class         = "db.t4g.micro"
  db_name                = local.postgres_name
  username               = local.postgres_user_name
  password               = local.postgres_user_password
  publicly_accessible    = true
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  tags = {
    Name = "PostgresDB"
  }
}

output "postgres_db_endpoint" {
  value = aws_db_instance.postgres_db.endpoint
}

# resource "aws_s3_bucket" "images_bucket" {
#   bucket = "marketplace-bucket"
#   acl    = "private"
#
#   tags = {
#     Name = "MarketplaceBucket"
#   }
# }

# resource "aws_s3_bucket_policy" "images_policy" {
#   bucket = aws_s3_bucket.images_bucket.id
#
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid       = "PublicAccessPermissions"
#         Effect    = "Allow"
#         Principal = "*"
#         Action    = [
#           "s3:GetObject",
#           "s3:PutObject",
#           "s3:DeleteObject"
#         ]
#         Resource  = "${aws_s3_bucket.images_bucket.arn}/*"
#       }
#     ]
#   })
# }
