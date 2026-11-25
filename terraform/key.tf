# CREATE AWS KEY PAIR

resource "aws_key_pair" "three_tier_key" {
  key_name   = "three-tier-key"
  public_key = file("C:/Users/Harris/.ssh/three_tier_key.pub")
}

# ssh -i ~/.ssh/three_tier_key ubuntu@ec2-54-206-124-32.ap-southeast-2.compute.amazonaws.com