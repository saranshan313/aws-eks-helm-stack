locals {
  regions = {
    "use1" = "us-east-1"
  }
  settings = yamldecode(file("${var.TFC_WORKSPACE_NAME}.yaml"))
}

provider "kubernetes" {
  host = data.terraform_remote_state.eks.outputs.eks_endpoint
  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.eks_ca)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.eks_cluster_name]
    command = "aws"
  }
}

data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "tf-remote-state-234-343-555"
    key    = "env:/eks-${local.settings.env}-${local.settings.region}/eks-${local.settings.env}-${local.settings.region}.tfstate"
    region = local.regions[local.settings.region]
  }
}

#data "aws_caller_identity" "current" {}
