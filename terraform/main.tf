############# Create a VPC #############
resource "aws_vpc" "EKS_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev"
  }
}


############# public subnet #############

#currently two subnets are defined
resource "aws_subnet" "EKS_public_subnet" {
  count = var.public_subnet_count

  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = "10.0.${count.index}.0/24"
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.EKS_vpc.id

  tags = {
    "Name"                                        = "dev-public-${count.index}"
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/terraform-eks-cluster" = "owned"
  }
}

resource "aws_route_table_association" "EKS_public_association" {
  count = var.public_subnet_count
  #count = 2

  subnet_id      = aws_subnet.EKS_public_subnet[count.index].id
  route_table_id = aws_route_table.EKS_public_rt.id
}

#rout table from the subnet to the igw
resource "aws_route_table" "EKS_public_rt" {
  vpc_id = aws_vpc.EKS_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.EKS_internet_gateway.id
  }
  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }

  tags = {
    Name = "public_rt"
  }
}

############# private subnet #############

#currently two subets are defined
resource "aws_subnet" "EKS_private_subnet" {
  count = var.private_subnet_count

  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = "10.0.${count.index + var.public_subnet_count + 2}.0/24"
  map_public_ip_on_launch = true
  vpc_id                  = aws_vpc.EKS_vpc.id

  tags = {
    "Name"                                        = "dev-private-${count.index}"
    "kubernetes.io/role/internal-elb"             = "1"
    "kubernetes.io/cluster/terraform-eks-cluster" = "owned"
  }
}

resource "aws_route_table_association" "EKS_private_association" {
  count = var.private_subnet_count
  #count = 2

  subnet_id      = aws_subnet.EKS_private_subnet[count.index].id
  route_table_id = aws_route_table.EKS_private_rt[count.index].id
}

resource "aws_route_table" "EKS_private_rt" {
  vpc_id = aws_vpc.EKS_vpc.id
  count  = var.private_subnet_count

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat[count.index].id
  }
  route {
    cidr_block = "10.0.0.0/16"
    gateway_id = "local"
  }

  tags = {
    Name = "private_rt"
  }
}

############# internet gateway #############

#igw for vpc
resource "aws_internet_gateway" "EKS_internet_gateway" {
  vpc_id = aws_vpc.EKS_vpc.id
  tags = {
    Name = "dev-igw"
  }
}

############# security group #############


#this needs to be updated with the needed ports
resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "dev security group"
  vpc_id      = aws_vpc.EKS_vpc.id

  ingress { #for cluster communication
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.EKS_vpc.cidr_block]
  }
  #load balancer
  ingress {
    description     = "load balancer"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    cidr_blocks = [aws_vpc.EKS_vpc.cidr_block]
  }
  ingress {
    description     = "Allow Node Exporter Access"
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    cidr_blocks = [aws_vpc.EKS_vpc.cidr_block]
  }
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  #bastion ssh
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }


  

  egress {
    from_port        = 0 #all ports
    to_port          = 0
    protocol         = "-1" #all protocols
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

#bastions security group
resource "aws_security_group" "bastion" {
  name        = "bastion_ssh"
  description = "bastion security group"
  vpc_id      = aws_vpc.EKS_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ssh connections"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

############# bastion #############

resource "aws_instance" "bastion" {

  count                  = var.public_subnet_count
  ami                    = data.aws_ami.bastion_ami.id
  instance_type          = "t2.micro"
  # subnet_id              = aws_subnet.EKS_public_subnet[count.index].id
  subnet_id              = aws_subnet.EKS_public_subnet[1].id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  #key_name               = aws_key_pair.bastion_auth.key_name
  key_name               = "bastionkey"

  # provisioner "local-exec"{     #this is to enable ssh will need to be done using something other than a provisioner later
  #   command = templatefile("ssh-config.tpl", {
  #     hostname = self.public_ip,
  #     user = "orwah",
  #     identityfile = "~/.ssh/bastionkey"
  #   })
  #   interpreter = ["bash","-c"]
  # }
  # ebs_block_device{
  #   volume_size = 2
  #   volume_type = "gp3"
  #   device_name =  "/dev/xvda"
  # }

}

############# bastion key pair #############
resource "aws_key_pair" "bastion_auth" {
  key_name   = "bastionkey"
  public_key = tls_private_key.rsa-4096.public_key_openssh
  #public_key = file("~/.ssh/bastionkey.pub")
}

resource "local_file" "TF_key" {
  content  = tls_private_key.rsa-4096.private_key_pem
  filename = "TFkey"
}

resource "tls_private_key" "rsa-4096"{
  algorithm = "RSA"
  rsa_bits = 4096
}


############# bastion extra ebs #############
#separate volume so it won't be deleted when restarting the instance
# resource "aws_ebs_volume" "bastion_volume" {
#   count             = var.public_subnet_count
#   size              = 2
#   type              = "gp3"
#   availability_zone = data.aws_availability_zones.available.names[count.index]
# }

# resource "aws_volume_attachment" "attachment" {
#   count       = var.public_subnet_count
#   volume_id   = aws_ebs_volume.bastion_volume[count.index].id
#   instance_id = aws_instance.bastion[count.index].id
#   device_name = "/dev/sdb"
# }



############# nacl #############

#only vpc level nacl (no subnet nacl) 
resource "aws_network_acl" "main" {
  vpc_id = aws_vpc.EKS_vpc.id

  egress {
    protocol   = "-1"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  ingress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "main"
  }
}
# resource "aws_launch_template" "bastion_launch_template" {
#   name = "bastionn_launch_template"

#   vpc_security_group_ids = [aws_security_group.allow_tls.id]

#   #   block_device_mappings {
#   #     device_name = "/dev/xvda"

#   #     ebs {
#   #       volume_size = 20
#   #       volume_type = "gp2"
#   #     }
#   #   }

#   image_id = data.aws_ami.bastion_ami.id
#   #instance_type = "t3.medium"
#   user_data = base64encode(<<-EOF
# MIME-Version: 1.0
# Content-Type: multipart/mixed; boundary="==MYBOUNDARY=="
# --==MYBOUNDARY==
# Content-Type: text/x-shellscript; charset="us-ascii"
# #!/bin/bash
# /etc/eks/bootstrap.sh your-eks-cluster
# --==MYBOUNDARY==--\
#   EOF
#   )

#   tag_specifications {
#     resource_type = "instance"

#     tags = {
#       Name = "bastion-MANAGED-NODE"
#     }
#   }
# }



# resource "aws_subnet" "EKS_public_subnet" {
#   vpc_id                  = aws_vpc.EKS_vpc.id
#   cidr_block              = "10.0.1.0/24"
#   map_public_ip_on_launch = true
#   availability_zone       = "us-east-1a"

#   tags = {
#     Name = "dev-public"
#   }
# }
