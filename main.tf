terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# ------------------------------------------------------------------------------
# 1. VPC Architecture for EKS Production
# ------------------------------------------------------------------------------
data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.environment}-vpc"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway     = true
  single_nat_gateway     = false # Multi-AZ HA setup for production
  one_nat_gateway_per_az = true
  enable_dns_hostnames   = true
  enable_dns_support     = true

  # Subnet tagging required by AWS Load Balancer Controller
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
  }
}

# ------------------------------------------------------------------------------
# 2. EKS Cluster Definition
# ------------------------------------------------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.30"
# Enable EKS API Access Entries
  enable_cluster_creator_admin_permissions = true
  authentication_mode                      = "API_AND_CONFIG_MAP"

  # Cluster Endpoint Security
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # IRSA for pod-level IAM roles
  enable_irsa = true

  # Encryption & Logging
  cluster_enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  # EKS Addons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  # Production Managed Node Groups
  eks_managed_node_groups = {
    general = {
      name         = "general-node-group"
      instance_types = ["m6i.large", "m5.large"]
# ADD/UPDATE THIS LINE HERE:
      ami_type      = "AL2023_x86_64_STANDARD"

      min_size     = 2
      max_size     = 10
      desired_size = 3

      capacity_type = "ON_DEMAND"
      
      # Ensure EBS volumes are encrypted
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 50
            volume_type           = "gp3"
            encrypted             = true
            delete_on_termination = true
          }
        }
      }

      iam_role_additional_policies = {
        AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      }
    }
  }
}

# ------------------------------------------------------------------------------
# 3. Kubernetes Provider Authentication
# ------------------------------------------------------------------------------
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}



provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

# ------------------------------------------------------------------------------
# 4. Sample Workload Deployment (Nginx / App)
# ------------------------------------------------------------------------------
resource "kubernetes_namespace" "app_ns" {
  depends_on = [module.eks]
  metadata {
    name = "sample-app"
    labels = {
      environment = var.environment
    }
  }
}

resource "kubernetes_deployment" "sample_app" {
  metadata {
    name      = "production-app"
    namespace = kubernetes_namespace.app_ns.metadata[0].name
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "production-app"
      }
    }

    template {
      metadata {
        labels = {
          app = "production-app"
        }
      }

      spec {
        container {
          image = "nginx:1.25-alpine"
          name  = "web"

          resources {
            limits = {
              cpu    = "250m"
              memory = "256Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }

          port {
            container_port = 80
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 2
            period_seconds        = 5
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "sample_app_svc" {
  metadata {
    name      = "production-app-service"
    namespace = kubernetes_namespace.app_ns.metadata[0].name
  }

  spec {
    selector = {
      app = kubernetes_deployment.sample_app.spec[0].template[0].metadata[0].labels.app
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "LoadBalancer"
  }
}
# ------------------------------------------------------------------------------
# 5. Post-Deployment Verification (Dedicated Null Resource)
# ------------------------------------------------------------------------------
resource "null_resource" "verify_deployment" {
  # Waits for the service and deployment to finish provisioning first
  depends_on = [
    kubernetes_service.sample_app_svc,
    kubernetes_deployment.sample_app
  ]

  provisioner "local-exec" {
    command = <<EOT
      aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}
      kubectl get nodes
      kubectl get pods -n sample-app
    EOT
  }
}