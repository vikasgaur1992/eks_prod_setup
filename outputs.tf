output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "load_balancer_hostname" {
  description = "External URL of the sample application service"
  value       = kubernetes_service.sample_app_svc.status[0].load_balancer[0].ingress[0].hostname
}
