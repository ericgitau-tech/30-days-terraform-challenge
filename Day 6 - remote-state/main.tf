# Create a simple EC2 instance to manage
resource "aws_instance" "example" {
  ami           = "ami-01652dfea70d0d9b9"
  instance_type = "t2.micro"

  tags = {
    Name = "Terraform-Example-Instance"
  }
}
