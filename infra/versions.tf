terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.0"
    }
  }

  backend "s3" {
    bucket      = "phone-code-tfstate"
    key         = "phone-code/terraform.tfstate"
    region      = "us-west-2"
    profile     = "phone-code"
    use_lockfile = true
    encrypt     = true
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "phone-code"
}
