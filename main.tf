resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet_a" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
}

resource "aws_subnet" "subnet_c" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1c"
}

resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_template" "apache_lt" {
  name_prefix = "apache-lt"
  image_id    = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  user_data     = base64encode(file("user_data.sh"))
  vpc_security_group_ids = [aws_security_group.web_sg.id]
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_lb" "alb" {
  name               = "apache-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = [aws_subnet.subnet_a.id, aws_subnet.subnet_c.id]
}

resource "aws_lb_target_group" "tg" {
  name     = "apache-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check {
    path = "/"
    interval = 30
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_autoscaling_group" "asg" {
  name                      = "apache-asg"
  max_size                  = var.max_size
  min_size                  = var.min_size
  desired_capacity          = var.desired_capacity
  vpc_zone_identifier       = [aws_subnet.subnet_a.id, aws_subnet.subnet_c.id]
  target_group_arns         = [aws_lb_target_group.tg.arn]
  health_check_type         = "ELB"

  launch_template {
    id      = aws_launch_template.apache_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "apache-asg-instance"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "cpu_scale_out" {
  name                   = "scale-out"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}
