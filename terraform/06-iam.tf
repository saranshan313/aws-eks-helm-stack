#IAM Role for the AWS ALB Ingress Controller
data "aws_iam_policy_document" "alb_controller_assume_policy" {

  statement {
    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"
      identifiers = [
        data.terraform_remote_state.eks.outputs.eks_oidc_arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(data.terraform_remote_state.eks.outputs.eks_oidc_issuer, "https://", "")}:sub"

      values = [
        "system:serviceaccount:${local.settings.alb_ingress_controller.namespace}:${local.settings.alb_ingress_controller.service_account}",
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(data.terraform_remote_state.eks.outputs.eks_oidc_issuer, "https://", "")}:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "alb_controller_role" {
  name               = "role-${local.settings.env}-${local.settings.region}-alb-controller-01"
  description        = "Role for the ALB Ingress Controller"
  assume_role_policy = data.aws_iam_policy_document.alb_controller_assume_policy.json
}

resource "aws_iam_policy" "alb_controller_permission_policy" {
  name        = "policy-${local.settings.env}-${local.settings.region}-alb-controller-01"
  path        = "/"
  description = "Permission policy for the ALB Ingress Controller"
  policy      = file("${path.module}/policies/ingress-permission.json")
}

resource "aws_iam_role_policy_attachment" "aws_alb_controller_permissions" {
  role       = aws_iam_role.alb_controller_role.name
  policy_arn = aws_iam_policy.alb_controller_permission_policy.arn
}

#IAM Role for the Karpenter Controller
data "aws_iam_policy_document" "karpenter_controller_assume_policy" {

  statement {
    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"
      identifiers = [
        data.terraform_remote_state.eks.outputs.eks_oidc_arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(data.terraform_remote_state.eks.outputs.eks_oidc_issuer, "https://", "")}:sub"

      values = [
        "system:serviceaccount:${local.settings.karpenter_controller.namespace}:${local.settings.karpenter_controller.service_account}",
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(data.terraform_remote_state.eks.outputs.eks_oidc_issuer, "https://", "")}:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    effect = "Allow"
  }
}

resource "aws_iam_role" "karpenter_controller_role" {
  name               = "role-${local.settings.env}-${local.settings.region}-karpenter-controller-01"
  description        = "Role for the Karpenter Controller"
  assume_role_policy = data.aws_iam_policy_document.karpenter_controller_assume_policy.json
}

resource "aws_iam_policy" "karpenter_controller_permission_policy" {
  name        = "policy-${local.settings.env}-${local.settings.region}-karpenter-controller-01"
  path        = "/"
  description = "Permission policy for the Karpenter Controller"
  policy = templatefile(
    "${path.module}/policies/karpenter-permission.json",
    {
      AWS_ACCOUNT_ID = "${data.aws_caller_identity.current.account_id}"
      CLUSTER_NAME   = "${data.terraform_remote_state.eks.outputs.eks_cluster_name}"
      AWS_REGION     = "${local.regions[local.settings.region]}"
    }
  )
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_permissions" {
  role       = aws_iam_role.karpenter_controller_role.name
  policy_arn = aws_iam_policy.karpenter_controller_permission_policy.arn
}
