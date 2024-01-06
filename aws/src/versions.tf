terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.31.0"
    }
    mcma = {
      source  = "ebu/mcma"
      version = ">= 0.0.27"
    }
  }
}
