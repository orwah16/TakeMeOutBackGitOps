resource "aws_eip" "nat" {
  count = var.public_subnet_count
  #vpc = true
  tags = {
    Name = "nat"
  }
}

resource "aws_nat_gateway" "nat" {
  count         = var.public_subnet_count
  allocation_id = element(aws_eip.nat.*.id, count.index)
  subnet_id     = aws_subnet.EKS_public_subnet[count.index].id


  tags = {
    Name = "nat-${count.index}"
  }

  depends_on = [aws_internet_gateway.EKS_internet_gateway]
}