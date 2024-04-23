#Add Admin user to AWS Auth Config Map to provide access to EKS Cluster
resource "kubernetes_config_map" "aws_auth" {
  for_each = local.settings.eks_cluster.aws_auth_config
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    userarn  = each.value["userarn"]
    username = each.value["username"]
    groups   = each.value["groups"]
  }

  lifecycle {
    # We are ignoring the data here since we will manage it with the resource below
    # This is only intended to be used in scenarios where the configmap does not exist
    ignore_changes = [
      data,
      metadata[0].labels,
      metadata[0].annotations
    ]
  }
}
