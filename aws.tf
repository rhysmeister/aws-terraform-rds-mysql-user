terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~>4.38.0"
        }
        mysql = {
        source = "nkhanal0/mysql"
        version = "2.0.3"
        }
    }
}

provider "aws" {
    region  = "eu-central-1"
    profile = "aws_terraform"
}

provider "mysql" {
  endpoint =  aws_db_instance.rds1.endpoint
  username = local.username
  password = local.password
}