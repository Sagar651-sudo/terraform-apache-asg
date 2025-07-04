#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<h1>Apache Web Server running via ASG + Terraform</h1>" > /var/www/html/index.html
