output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = data.aws_eks_cluster.platform.name
}

output "eks_cluster_endpoint" {
  description = "Endpoint of the EKS cluster"
  value       = data.aws_eks_cluster.platform.endpoint
}

output "app_pod_role_arn" {
  description = "ARN of the IRSA role for application pods"
  value       = data.aws_iam_role.app_pod.arn
}
