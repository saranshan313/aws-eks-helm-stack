output "eks_lb_dns_name" {
  description = "DNS Name of the EKS Load Balancer"
  value       = try(aws_lb.eks_alb.dns_name, null)
}

output "eks_endpoint" {
  description = "Endpoint of the EKS Cluster"
  value       = try(aws_eks_cluster.eks_apps.endpoint, null)
}

output "eks_ca" {
  description = "CA of the EKS Cluster"
  value       = try(aws_eks_cluster.eks_apps.certificate_authority[0].data, null)
}

output "eks_oidc" {
  description = "OIDC of the EKS Cluster"
  value       = try(aws_eks_cluster.eks_apps.identity[0].oidc[0].issuer, null)
}

output "eks_cluster_name" {
  description = "Name of the EKS Cluster"
  value       = try(aws_eks_cluster.eks_apps.id, null)
}
