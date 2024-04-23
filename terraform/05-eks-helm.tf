#Add Admin user to AWS Auth Config Map to provide access to EKS Cluster
# resource "kubernetes_config_map" "aws_auth" {
#   for_each = local.settings.eks_cluster.aws_auth_config
#   metadata {
#     name      = "aws-auth"
#     namespace = "kube-system"
#   }

#   data = {
#     userarn  = each.value["userarn"]
#     username = each.value["username"]
#     groups   = each.value["groups"]
#   }

#   lifecycle {
#     # We are ignoring the data here since we will manage it with the resource below
#     # This is only intended to be used in scenarios where the configmap does not exist
#     ignore_changes = [
#       data,
#       metadata[0].labels,
#       metadata[0].annotations
#     ]
#   }
# }
locals {
  aws_auth_configmap_data = yamlencode({
    "data" : {
      mapRoles : yamlencode(data.kubernetes_config_map.deafult_aws_auth.data.mapRoles)
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