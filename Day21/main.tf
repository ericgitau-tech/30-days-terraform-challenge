# This tells Terraform to use AWS in eu-west-1 (Ireland)
provider "aws" {
  region = "eu-west-1"
}

# This creates one EC2 instance
resource "aws_instance" "web" {
  ami           = "ami-0c1c30571d2dae5be"
  instance_type = "t2.large"

  tags = {
    Name = "day21-test-server"
  }
}