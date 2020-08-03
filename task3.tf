provider "aws" {
  region     = "ap-south-1"
  profile = "aditi"

}

resource "aws_vpc" "my_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"


  tags = {
    Name = "wp_vpc"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "ap-south-1a"


  tags = {
    Name = "public_subnet"
  }

  depends_on = [ 
      aws_vpc.my_vpc,
    ]
}


resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1a"


  tags = {
    Name = "private_subnet"
  }

  depends_on = [ 
      aws_vpc.my_vpc,
    ]
}

resource "aws_internet_gateway" "wp_gw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "Internet_gateway"
  }

  depends_on = [ 
      aws_vpc.my_vpc,
    ]
}


resource "aws_route_table" "route_table" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.wp_gw.id
  }
  tags = {
    Name = "route_table"
  }

  depends_on = [ 
      aws_internet_gateway.wp_gw, 
    ]
}
resource "aws_route_table_association" "rt_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.route_table.id
  depends_on = [ 
      aws_route_table.route_table, 
      ]
}

resource "aws_security_group" "wordpress_sg" {
  name        = "wordpress"
  description = "To connect with wordpress instance"
  vpc_id      = aws_vpc.my_vpc.id


  ingress {
    description = "Http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  ingress {
    description = "ICMP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
   ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }




  tags = {
    Name = "sgroup_wordpress"
  }


  depends_on = [ 
      aws_vpc.my_vpc, 
      ]
}

resource "aws_security_group" "mysql_sg" {
  name        = "mysql"
  description = "connect to mysql instance"
  vpc_id      = aws_vpc.my_vpc.id


  ingress {
    description = "MYSQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sgroup_mysql"
  }

  depends_on = [ 
      aws_vpc.my_vpc, 
      ]
}

resource "tls_private_key" "mykey" {
  algorithm   = "RSA"
  rsa_bits = 4096
  
  depends_on = [
      aws_security_group.wordpress_sg,
      aws_security_group.mysql_sg
      ]
}

resource "local_file" "private-key" {
    content     = tls_private_key.mykey.private_key_pem
    filename    = "keyx.pem"
}

resource "aws_key_pair" "wp_key" {
  key_name   = "mykey18"
  public_key = tls_private_key.mykey.public_key_openssh

  depends_on = [
      tls_private_key.mykey
      ]
}

resource "aws_instance" "wordpress" {
  ami           = "ami-7e257211"
  instance_type = "t2.micro"
  key_name      =  aws_key_pair.wp_key.key_name
  subnet_id     = "${aws_subnet.public_subnet.id}"
  availability_zone = "ap-south-1a"
  vpc_security_group_ids = [ "${aws_security_group.wordpress_sg.id}" ]
  tags = {
    Name = "Wordpress_instance"
  }
  depends_on = [ 
      aws_subnet.public_subnet, 
      ]
}


resource "aws_instance" "mysql" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.wp_key.key_name
  subnet_id     = "${aws_subnet.private_subnet.id}"
  vpc_security_group_ids = [ "${aws_security_group.mysql_sg.id}" ]
  availability_zone = "ap-south-1a"
  tags = {
    Name = "MYSQL_instance"
  }
  depends_on = [ 
      aws_subnet.private_subnet, 
      ]
}

output "public_ip" {
    value = "${aws_instance.wordpress.public_ip}"
}

