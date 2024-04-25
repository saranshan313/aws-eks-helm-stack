locals {
  regions = {
    "use1" = "us-east-1"
  }
  settings = yamldecode(file("${var.TFC_WORKSPACE_NAME}.yaml"))
}

provider "aws" {
  region = local.regions[local.settings.region]

  default_tags {
    tags = {
      region = local.settings.region
      env    = local.settings.env
    }
  }
}

provider "kubernetes" {
  host                   = data.terraform_remote_state.eks.outputs.eks_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.eks_ca)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.eks_cluster_name]
    command     = "aws"
  }
}

provider "kubectl" {
  host                   = data.terraform_remote_state.eks.outputs.eks_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.eks_ca)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.eks_cluster_name]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes {
    host                   = data.terraform_remote_state.eks.outputs.eks_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.eks_ca)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.eks_cluster_name]
      command     = "aws"
    }
  }
}

data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "tf-remote-state-234-343-555-666"
    key    = "env:/eks-${local.settings.env}-${local.settings.region}/eks-${local.settings.env}-${local.settings.region}.tfstate"
    region = local.regions[local.settings.region]
  }
}

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = "tf-remote-state-234-343-555-666"
    key    = "env:/infra-${local.settings.env}-${local.settings.region}/infra-${local.settings.env}-${local.settings.region}.tfstate"
    region = local.regions[local.settings.region]
  }
}

data "aws_caller_identity" "current" {}

#data "aws_region" "current" {}


#Data to fetch existing AWS auth config data
data "kubernetes_config_map" "deafult_aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }
}
