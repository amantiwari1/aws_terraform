provider "aws" {
  profile =  "aman1"
  region  = "ap-south-1"
}


// SSH RSA Generate 

resource "tls_private_key" "webserver_private_key" {
 algorithm = "RSA"
 rsa_bits = 4096

}


// Create the key pairs 

resource "local_file" "private_key" {
 content = tls_private_key.webserver_private_key.private_key_pem
 filename = "webserver_key.pem"
 file_permission = 0400

}


resource "aws_key_pair" "webserver_key" {
 key_name = "webserver"
 public_key = tls_private_key.webserver_private_key.public_key_openssh

}


// Create Security Groups (Firewall) including http and SSH

resource "aws_security_group" "allow_http_ssh" {

  name        = "allow_http" 
  description = "Allow http inbound traffic"
  vpc_id      = "vpc-075e88e4d7296ca92"

ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  } 


  ingress {
    description = "ssh"
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


resource "aws_instance" "web" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = aws_key_pair.webserver_key.key_name
  security_groups = [aws_security_group.allow_http_ssh.name]



provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]

  connection {
  type     = "ssh"
  user     = "ec2-user"
  private_key = tls_private_key.webserver_private_key.private_key_pem
  host     = aws_instance.web.public_ip
}
  }

  tags = {
    Name = "Web"
  }

 }

resource "aws_ebs_volume" "esb1" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1
  tags = {
    Name = "lwebs"
  }
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.esb1.id}"
  instance_id = "${aws_instance.web.id}"
  force_detach = true
}

resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebs_att,
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    port    = 22
    private_key = tls_private_key.webserver_private_key.private_key_pem
    host     = aws_instance.web.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/amantiwari1/amantiwari1.github.io.git /var/www/html/"
    ]
  }
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = "webserverimages1234"
  acl    = "public-read"
}




# Saving name of the bucket to local system
resource "null_resource" "null2" {
  depends_on = [
      aws_s3_bucket.my_bucket,
]
  provisioner "local-exec" {
    command = "echo ${aws_s3_bucket.my_bucket.bucket} > bucket_name.txt"
  } 
}

resource "null_resource" "null" {
  provisioner "local-exec" {
    command = "git clone https://github.com/amantiwari1/amantiwari1.github.io.git"
  } 
}

resource "aws_s3_bucket_object" "object1" {
  depends_on =[
      null_resource.null,
      aws_s3_bucket.my_bucket
]
  bucket = aws_s3_bucket.my_bucket.bucket
  key    = "aman.png"
  source = "I:/aman/terra/amantiwari1.github.io/assets/img/aman.png"
  acl    = "public-read"
} 

resource "aws_cloudfront_distribution" "s3_distribution" { 
  origin {
    domain_name = aws_s3_bucket.my_bucket.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.my_bucket.bucket
  }
  enabled = true
    default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.my_bucket.bucket
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

output "cloudfront"{
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}

resource "null_resource" "nulll" {
  depends_on = [
      aws_cloudfront_distribution.s3_distribution,
      null_resource.null,   
]
  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = tls_private_key.webserver_private_key.private_key_pem
    host        = aws_instance.web.public_ip
  }
  provisioner "remote-exec" {
      inline = [ 
        # sudo su << \"EOF\" \n echo \"<img src='${aws_cloudfront_distribution.s3_distribution.domain_name}'>\" >> /var/www/html/index.html \n \"EOF\"
            "sudo su << EOF",
         "echo \"<img src='http://${aws_cloudfront_distribution.s3_distribution.domain_name}/${aws_s3_bucket_object.object1.key}'>\" >> /var/www/html/index.html",
          "EOF"
     ]
  }

}




output "myos_ip" {
  value = aws_instance.web.public_ip
}


  