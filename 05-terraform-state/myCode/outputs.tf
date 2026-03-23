output "alb_dns_name" {
  value       = aws_lb.example.dns_name
  description = "The domain name of the load balancer"
}

output "alb_arn" {
  value       = aws_lb.example.arn
  description = "The ARN of the load balancer"
}