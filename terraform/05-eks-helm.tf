#Add Admin user to AWS Auth Config Map to provide access to EKS Cluster
locals {
  aws_auth_configmap_data = yamlencode({
    "data" : {
      mapRoles : data.kubernetes_config_map.deafult_aws_auth.data.mapRoles
      mapUsers : yamlencode(local.settings.eks_cluster.aws_auth_config.cluster_admin)
      #      mapAccounts = yamlencode(local.map_accounts)
    }
  })
}

resource "kubectl_manifest" "aws_auth" {
  yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    app.kubernetes.io/managed-by: Terraform
  name: aws-auth
  namespace: kube-system
${local.aws_auth_configmap_data}
YAML
}

#Install ALB Ingress Controller
resource "helm_release" "alb_controller" {

  name       = local.settings.alb_ingress_controller.chart_name
  chart      = local.settings.alb_ingress_controller.chart_release_name
  repository = local.settings.alb_ingress_controller.chart_repo_url
  version    = local.settings.alb_ingress_controller.chart_version
  namespace  = local.settings.alb_ingress_controller.namespace

  create_namespace = local.settings.alb_ingress_controller.create_namespace

  set {
    name  = "clusterName"
    value = data.terraform_remote_state.eks.outputs.eks_cluster_name
  }

  set {
    name  = "awsRegion"
    value = local.regions[local.settings.region]
  }

  set {
    name  = "rbac.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = local.settings.alb_ingress_controller.service_account
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.alb_controller_role.arn
  }

  set {
    name  = "enableServiceMutatorWebhook"
    value = "false"
  }

}

#Install Karpenter Controller
resource "aws_ec2_tag" "applications_subnets" {
  for_each    = data.terraform_remote_state.vpc.outputs.network_application_subnets
  resource_id = each.value
  key         = "Key=karpenter.sh/discovery"
  value       = data.terraform_remote_state.eks.outputs.eks_cluster_name
}

resource "aws_ec2_tag" "nodegrp_sgs" {
  for_each    = toset(data.terraform_remote_state.vpc.outputs.eks_nodegrp_sgs)
  resource_id = each.value
  key         = "Key=karpenter.sh/discovery"
  value       = data.terraform_remote_state.eks.outputs.eks_cluster_name
}