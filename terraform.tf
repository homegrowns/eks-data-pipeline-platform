# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

terraform {

  required_version = "~> 1.3"
  # cloud {
  #   workspaces {
  #     name = "learn-terraform-eks"
  #   }
  # }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.47.0"
    }
    
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31" 
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.1"
    }

    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0.5"
    }

    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~> 2.3.4"
    }


    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.1"
    }
  }

    backend "s3" {
    bucket         = "eks-airflow-bucket"
    key            = "terraform/eks-airflow-cluster/terraform.tfstate"
    region         = "ap-northeast-2"
    use_lockfile   = true
    dynamodb_table = "eks-airflow-terraform-lock"
  }

# 1.terraform init (backend "s3"  주석처리후 실행)
# 2.terraform apply  # -> 여기서 S3와 DynamoDB가 실제로 생성됨
# 3.terraform init (backend "s3"  주석제거후 실행)
}
