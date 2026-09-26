# ------------------------------------------------------------------------------
# 1. EKS Cluster & Control Plane Details
# ------------------------------------------------------------------------------
output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane API"
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version running on the control plane"
  value       = module.eks.cluster_version
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS control plane"
  value       = module.eks.cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for IAM Roles for Service Accounts (IRSA)"
  value       = module.eks.oidc_provider_arn
}

# ------------------------------------------------------------------------------
# 2. Managed Node Groups Information
# ------------------------------------------------------------------------------
output "eks_managed_node_groups" {
  description = "Map of active managed node groups and their properties"
  value = {
    for k, v in module.eks.eks_managed_node_groups : k => {
      node_group_id   = v.node_group_id
      node_group_arn  = v.node_group_arn
      status          = v.node_group_status
      autoscaling_grp = v.node_group_autoscaling_group_names
    }
  }
}

# ------------------------------------------------------------------------------
# 3. VPC & Network Infrastructure
# ------------------------------------------------------------------------------
output "vpc_id" {
  description = "VPC ID where the cluster is deployed"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "IDs of the private subnets hosting worker nodes"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "IDs of the public subnets hosting load balancers"
  value       = module.vpc.public_subnets
}

output "nat_public_ips" {
  description = "List of public Elastic IP addresses created for the NAT Gateways"
  value       = module.vpc.nat_public_ips
}

# ------------------------------------------------------------------------------
# 4. Velero Backup Infrastructure
# ------------------------------------------------------------------------------
output "velero_s3_bucket_name" {
  description = "Name of the S3 bucket provisioned for Velero backups"
  value       = aws_s3_bucket.velero_backups.id
}

output "velero_irsa_role_arn" {
  description = "IAM Role ARN mapped to Velero ServiceAccount"
  value       = module.velero_irsa_role.iam_role_arn
}

# ------------------------------------------------------------------------------
# 5. Application Workload & Command Quick-Start
# ------------------------------------------------------------------------------
output "load_balancer_hostname" {
  description = "External DNS URL of the sample application load balancer"
  value       = try(kubernetes_service.sample_app_svc.status[0].load_balancer[0].ingress[0].hostname, "Pending provisioning...")
}

output "configure_kubectl_command" {
  description = "CLI Command to update local kubeconfig and connect to the cluster"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}