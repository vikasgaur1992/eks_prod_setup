variable "region" {
  type        = string
  default     = "us-east-1"
  description = "AWS Region"
}

variable "environment" {
  type        = string
  default     = "prod"
  description = "Deployment environment"
}

variable "cluster_name" {
  type        = string
  default     = "prod-eks-cluster"
  description = "EKS Cluster Name"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "VPC CIDR block"
}
