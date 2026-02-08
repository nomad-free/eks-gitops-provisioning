terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.84"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }


  }
  backend "s3" {}
}




provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "exchange-settlement"
      Environment = var.environment
      ManagedBy   = "terraform"
      Repository  = "nomad-free/eks-gitops-provisioning"
    }
  }
}



provider "helm" {
  kubernetes {
    host                   = module.cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(module.cluster.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name", module.cluster.cluster_name,
        "--region", var.aws_region
      ]
    }
  }
}