# resource "aws_route53_record" "www" {
#   zone_id = aws_route53_zone.primary.zone_id
#   name    = "takemeout"
#   type    = "CNAME"
#   ttl     = 300
#   records = [aws_eip.lb.public_ip] #need to pass the loadbalancer endpoint
# }

resource "aws_route53_zone" "public" {
  name = "dev.com"
  vpc {
    vpc_id = aws_vpc.EKS_vpc.id
  }
}