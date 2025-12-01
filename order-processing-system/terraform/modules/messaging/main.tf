data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "rabbitmq" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"
  subnet_id     = var.public_subnet_id
  
  vpc_security_group_ids = [var.rabbitmq_security_group_id]
  
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install docker -y
              service docker start
              usermod -a -G docker ec2-user
              docker run -d --name rabbitmq \
                --restart unless-stopped \
                -p 5672:5672 \
                -p 15672:15672 \
                -e RABBITMQ_DEFAULT_USER=guest \
                -e RABBITMQ_DEFAULT_PASS=guest \
                rabbitmq:3.12-management
              EOF

  tags = {
    Name = "${var.project_name}-rabbitmq"
  }
}