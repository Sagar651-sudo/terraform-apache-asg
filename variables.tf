variable "aws_region" {
  default = "ap-south-1"
}
variable "instance_type" {
  default = "t2.micro"
}
variable "desired_capacity" {
  default = 2
}
variable "min_size" {
  default = 1
}
variable "max_size" {
  default = 3
}
