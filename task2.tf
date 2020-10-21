provider "aws" {
region ="ap-south-1"
profile ="Akshit"
}

variable "s3-name" {
  type = string
  default="akshit-test-bucket"
}

resource "aws_security_group" "sec_grp" {
 name = "HTTP&SSH"
 ingress {
    description = "TLS from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "TLS from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
 }

 
 output "security_group"{
 value= aws_security_group.sec_grp.name
}
/*
resource "aws_key_pair" "key_pair" {
  key_name   = "deployer-key"
  public_key = file("/home/invincible/Desktop/terraform/task1/task1_key.pub.pub")
}*/

resource "aws_instance"  "webs" {
  ami           = "ami-0e306788ff2473ccb"
  instance_type = "t2.micro"
  key_name	= "mykey"
  security_groups =  [ aws_security_group.sec_grp.name ] 
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("/home/invincible/Downloads/mykey.pem")
    host     = aws_instance.webs.public_ip
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd amazon-efs-utils httpd  php git -y",
      "sudo systemctl start httpd",
      "sudo systemctl enable httpd"
    ]
  }

  tags = {
    Name = "webs1"
  }
}

resource "aws_efs_file_system" "webs" {
  creation_token = "webs"

  tags = {
    Name = "webs"
  }
}


resource "aws_s3_bucket" "s3b" {
  bucket = var.s3-name
  acl    = "public-read-write"
  force_destroy=true
}


resource "aws_s3_bucket_object" "object" {
  depends_on=[aws_s3_bucket.s3b]
  bucket = "akshit-test-bucket"
  key    = "goku.jpeg"
  acl    = "public-read"
  source = "/home/invincible/Downloads/(JPEG Image, 474 × 313 pixels).jpeg"
}

output "s3_domain_name" {
depends_on=[ aws_s3_bucket.s3b ]
value= "S3-${var.s3-name }"
}

resource "aws_cloudfront_distribution" "s3b" {
  depends_on=[aws_s3_bucket.s3b]
  
  origin {
    domain_name = aws_s3_bucket.s3b.bucket_regional_domain_name
    origin_id   = "S3-${var.s3-name}"
    }
    enabled             = true
    is_ipv6_enabled     = true
    
    default_cache_behavior {
    target_origin_id= "S3-${var.s3-name}"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    
    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
    
    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    }
    
    restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

    
    viewer_certificate {
    cloudfront_default_certificate = true
  }
}

output "cdn-domain"{
depends_on=[ aws_cloudfront_distribution.s3b ]
value= aws_cloudfront_distribution.s3b.domain_name
}

resource "aws_efs_mount_target" "alpha" {
  depends_on = [
    aws_efs_file_system.webs, 
    aws_instance.webs ]
  file_system_id = aws_efs_file_system.webs.id
  subnet_id = aws_instance.webs.subnet_id
  
  }
  
output "efs_id"{
value=aws_efs_file_system.webs.id

}  
  
  

resource "null_resource" "conn"{
  depends_on = [aws_cloudfront_distribution.s3b,
                aws_instance.webs,
                aws_efs_mount_target.alpha]
 connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("/home/invincible/Downloads/mykey.pem")
    host        = aws_instance.webs.public_ip
  }

 provisioner "remote-exec" {
    inline = [
      "sudo mount -t efs -o tls ${aws_efs_file_system.webs.id}:/ /var/www/html",
      "sudo su <<END",
      "echo \"<img src='http://${aws_cloudfront_distribution.s3b.domain_name}/${aws_s3_bucket_object.object.key}' >\" >> /var/www/html/myweb.html",
      "END",
    ]
  }

}


output "local-exec" {
    value = "url: http://${aws_instance.webs.public_ip}/myweb.html"
   }



