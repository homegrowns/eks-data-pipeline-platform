output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "vpc_endpoint_sg_id" {
  description = "vpc 엔드포인트 SG"
  value       = aws_security_group.vpc_endpoint_sg.id
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}
# output "cluster_ca" {
#   value = module.eks.cluster_certificate_authority_data
# }

output "airflow_rds_endpoint" {
  value = aws_db_instance.airflow_db.endpoint
}

output "airflow_rds_address" {
  value = aws_db_instance.airflow_db.address
}

output "alb_controller_role_arn" {
  value = module.alb_controller_irsa.iam_role_arn
}

output "Airflow_Worker_S3_role_arn" {
  value = module.irsa-airflow-worker.iam_role_arn
}

output "debug_fargate_network_check" {
  description = "Fargate 네트워크 경로 진단을 위한 정보"
  value = {
    fargate_profile_subnets = module.eks.fargate_profiles.airflow_worker
    vpc_private_route_table_ids = module.vpc.private_route_table_ids
    nat_gateway_ids          = module.vpc.natgw_ids
  }
}