provider "aws" {
  region = "ap-northeast-1"
}

terraform {

  required_version = ">= 0.15"

  backend "local" {
    path = "terraform.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.38.0"
    }
  }
}
