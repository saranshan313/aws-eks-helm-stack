#Add Admin user to AWS Auth Config Map to provide access to EKS Cluster
locals {
  aws_auth_configmap_data = yamlencode({
    "data" : {
      #mapRoles : yamlencode(concat(yamldecode(data.kubernetes_config_map.deafult_aws_auth.data.mapRoles), local.settings.eks_cluster.aws_auth_config.cluster_admin))
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
  #repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  #repository_password = data.aws_ecrpublic_authorization_token.token.password
  version   = local.settings.alb_ingress_controller.chart_version
  namespace = local.settings.alb_ingress_controller.namespace

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

  # set {
  #   name  = "image.repository"
  #   value = "602401143452.dkr.ecr.${local.regions[local.settings.region]}.amazonaws.com/amazon/aws-load-balancer-controller"
  # }

  # set {
  #   name  = "image.tag"
  #   value = "v2.7.2"
  # }

}

#Install Karpenter Controller
resource "aws_ec2_tag" "applications_subnets" {
  for_each    = data.terraform_remote_state.vpc.outputs.network_application_subnets
  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = data.terraform_remote_state.eks.outputs.eks_cluster_name
}

resource "aws_ec2_tag" "nodegrp_sgs" {
  for_each    = toset(data.terraform_remote_state.eks.outputs.eks_nodegrp_sgs)
  resource_id = each.value
  key         = "karpenter.sh/discovery"
  value       = data.terraform_remote_state.eks.outputs.eks_cluster_name
}

resource "helm_release" "karpenter_controller" {
  name       = local.settings.karpenter_controller.chart_name
  chart      = local.settings.karpenter_controller.chart_release_name
  repository = local.settings.karpenter_controller.chart_repo_url
  #repository_username = data.aws_ecrpublic_authorization_token.token.user_name
  #repository_password = data.aws_ecrpublic_authorization_token.token.password
  version          = local.settings.karpenter_controller.chart_version
  namespace        = local.settings.karpenter_controller.namespace
  wait             = false
  create_namespace = local.settings.karpenter_controller.create_namespace

  set {
    name  = "settings.clusterName"
    value = data.terraform_remote_state.eks.outputs.eks_cluster_name
  }

  set {
    name  = "settings.clusterEndpoint"
    value = data.terraform_remote_state.eks.outputs.eks_endpoint
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
    value = local.settings.karpenter_controller.service_account
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.karpenter_controller_role.arn
  }

  set {
    name  = "defaultInstanceProfile"
    value = data.terraform_remote_state.eks.outputs.eks_node_instance_profile_arn
  }

  # set {
  #   name  = "image.repository"
  #   value = "public.ecr.aws/karpenter/controller"
  # }

  # set {
  #   name  = "image.tag"
  #   value = "0.36.1"
  # }
}

resource "kubectl_manifest" "karpenter_crd_nodepool" {
  for_each  = data.kubectl_file_documents.karpenter_nodepool_crd.manifests
  yaml_body = each.value
}

resource "kubectl_manifest" "karpenter_crd_nodeclass" {
  for_each  = data.kubectl_file_documents.karpenter_nodeclass_crd.manifests
  yaml_body = each.value
}

resource "kubectl_manifest" "karpenter_crd_nodeclaim" {
  for_each  = data.kubectl_file_documents.karpenter_nodeclaim_crd.manifests
  yaml_body = each.value
}

resource "kubectl_manifest" "karpenter_nodepool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1beta1
    kind: NodePool
    metadata:
      name: default
    spec:
      template:
        spec:
          requirements:
            - key: kubernetes.io/arch
              operator: In
              values: ["amd64"]
            - key: kubernetes.io/os
              operator: In
              values: ["linux"]
            - key: karpenter.sh/capacity-type
              operator: In
              values: ["spot"]
            - key: karpenter.k8s.aws/instance-category
              operator: In
              values: ["t", "m"]
            - key: karpenter.k8s.aws/instance-generation
              operator: Gt
              values: ["2"]
            - key: karpenter.k8s.aws/instance-family
              operator: In
              values: ["m5", "t3"]
            - key: karpenter.k8s.aws/instance-cpu
              operator: In
              values: ["2"]
          nodeClassRef:
            apiVersion: karpenter.k8s.aws/v1beta1
            kind: EC2NodeClass
            name: default
      limits:
        cpu: 1000
      disruption:
        consolidationPolicy: WhenUnderutilized
        expireAfter: 720h # 30 * 24h = 720h
  YAML

  depends_on = [
    helm_release.karpenter_controller
  ]
}

resource "kubectl_manifest" "karpenter_ec2nodeclass" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1beta1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiFamily: AL2 # Amazon Linux 2
      instanceProfile: "${data.terraform_remote_state.eks.outputs.eks_node_instance_profile_name}"
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: "${data.terraform_remote_state.eks.outputs.eks_cluster_name}"
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: "${data.terraform_remote_state.eks.outputs.eks_cluster_name}"
  YAML

  depends_on = [
    helm_release.karpenter_controller
  ]
}
