# AWS PROVIDER CONFIGURATION

provider "aws" {
  region = "ap-southeast-2"
}

# CREATE EC2 INSTANCE

resource "aws_instance" "three_tier_server" {

  ami           = "ami-0dd60a46ecc6eac16"
  instance_type = "t2.medium"

  # Associate SSH Key Pair
  key_name = aws_key_pair.three_tier_key.key_name

  # Associate EC2 with Public Subnet
  subnet_id = aws_subnet.public_subnet.id

  # Associate Frontend Security Group
  vpc_security_group_ids = [
    aws_security_group.frontend_sg.id
  ]

  # Enable Public IP
  associate_public_ip_address = true

  tags = {
    Name = "three_tier_server"
  }
}