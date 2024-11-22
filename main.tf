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

resource "aws_instance" "marketplace_server" {
  ami           = "ami-017095afb82994ac7"
  instance_type = "t2.micro"
  vpc_security_group_ids = ["vpc-0e7c71931beabe4d1"]
  subnet_id              = "subnet-080523af6d34adba6"

  tags = {
    Name = "MarketplaceServerInstance"
  }
}
