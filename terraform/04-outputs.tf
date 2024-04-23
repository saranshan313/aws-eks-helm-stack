output "aws_auth_data" {
  description = "Data of the AWS Auth Config map"
  value       = try(yamldecode(data.kubernetes_config_map.deafult_aws_auth.data), null)
}

