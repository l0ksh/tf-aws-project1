provider "aws" {
  region     = "ap-south-1"
  access_key = "AKIAUOHLAYWCWR6EO5XI"
  secret_key = "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"
}

# 1. Create VPC

resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "production"
  }
}

# 2. Create internal gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id
}

# 3. Create custom route table

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "prod"
  }
}

# 4. Create a subnet

resource "aws_subnet" "subnet-1" {
    vpc_id = aws_vpc.prod-vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "ap-south-1a"

    tags = {
        Name = "prod-subnet"
    }
}

# 5. Associate subnet with route table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}

# 6. Create security group to allow port  22,80,443

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]        # allow all ipv4 ips
    ipv6_cidr_blocks = ["::/0"]             # allow all ipv6 ips
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"     # here -1 means any port
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# 7. Create a network interface with an ip in the subnet that was created in step 4

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

}

# 8. Assign an elastic ip to the network interface created in step 7

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]  # depends_on takes list as parameter
}

# 9. Create Ubuntu server and install/enable apache2

#resource "aws_key_pair" "main-key" {
#  key_name   = "main-key"
#  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC7cHs20emg88x4MT3ea3Klm5eu0DhTxNfyQWwwYdfwVPk549iuY7C7C+OQrpbFVrSS6B/rGz0JWVYjk0M5OCykiIh7WJhY2YnQ+wcSF00Hc2EcujCDl7WWbUtR7BK/Ps/8DbVblZ1X5PYvQrdW61snTDpQ5ywgp8csqCh8m2k2hJwMHQC0Hk860EmDEotKzCAua8MLcNxwvXIKWOcBCsfftjQt9XotnJ47uFQfZ2jTCNcM/jLrYyBXM/RKJdGW8xg1qFGSa1eZaXKwfii9ynLIrWiLlXqUeezZ4Giiu2EV2SACFipyMDrPL3tau8gQbJESD+5Kr+fRosHdRq1sJ4dh0F5TXThG7EZCp/BfhrzwGGc8YN3olpTfDu980plPFOh99rUNx6Yq6rOs9D4TkL6hXnarvUcRr5iFvGW0Bn/KDjD3elXN5go/O1cRuJKwkGeMq0LgnYJDGFwHA2lOHa7T/7Au6y6DoBlAL3rtI1GTElhRbviYbYqZuO6aMrsraQM= l0ksh@pop-os"
#}

resource "aws_instance" "srv1" {
  ami               = "ami-06984ea821ac0a879"
  instance_type     = "t2.micro"
  availability_zone = "ap-south-1a"
  key_name          = "LokeshSSH"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo My first web server > /var/www/html/index.html'
                EOF

  tags = {
    Name = "web-server"
  }
}


# Note - Make to sure hard-code availability_zone for subnet and instances so that the resources
# will be created on same zone. Also to avoid network issues.


#resource "<provider>_<resource_type>" "name" {
#    config options...
#    key = "value"
#    key2 = "value2"
#}      
