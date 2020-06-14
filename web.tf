provider "aws" {
  profile =  "aman1"
  region  = "ap-south-1"
}

resource "tls_private_key" "webserver_private_key" {
 algorithm = "RSA"
 rsa_bits = 4096

}



resource "local_file" "private_key" {

 content = tls_private_key.webserver_private_key.private_key_pem

 filename = "webserver_key.pem"

 file_permission = 0400

}

resource "aws_key_pair" "webserver_key" {

 key_name = "webserver"

 public_key = tls_private_key.webserver_private_key.public_key_openssh

}

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
  bucket = "webserver_images1234"
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



output "myos_ip" {
  value = aws_instance.web.public_ip
}


  