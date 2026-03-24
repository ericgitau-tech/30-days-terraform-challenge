terraform {
  backend "s3" {
    bucket         = "terraform-state-lab-c6d3f17f"
    key            = "terraform.tfstate"
    region         = "eu-west-1"
    use_lockfile   = true
    encrypt        = true
  }
}
