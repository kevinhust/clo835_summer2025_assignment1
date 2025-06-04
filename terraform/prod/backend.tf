terraform {
  backend "s3" {
    bucket = "col835a1kw"
    key    = "terraform_state/prod/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
  }
} 