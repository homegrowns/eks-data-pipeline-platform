# data aws_iam_policy는 권한 레시피를 조회하는 것이고,
# module irsa-ebs-csi는 그 레시피를 붙인 IRSA 전용 IAM Role을 만드는 역할이다.
module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.39.0"

  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
  # oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-driver"]
}

# Airflow 워커 전용 IRSA (S3 접근용)
module "irsa-airflow-worker" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.39.0"

  create_role      = true
  role_name        = "AirflowWorkerS3Role-${module.eks.cluster_name}"
  provider_url     = module.eks.oidc_provider
  
  # 1. 여기에 S3 접근 권한 정책 ARN을 넣습니다.
  # (S3 정책을 미리 만드셨다면 해당 ARN을 넣고, 없으면 아래 3번 참고)
  role_policy_arns = [aws_iam_policy.airflow_s3_log_policy.arn]

  # 2. 중요: Airflow 워커 전용 서비스 어카운트 지정
  # 네임스페이스: airflow, 서비스어카운트명: airflow-worker (values.yaml 설정과 맞춰야 함)
  oidc_fully_qualified_subjects = [
  "system:serviceaccount:airflow:airflow-worker",
  "system:serviceaccount:airflow:airflow-scheduler",
  "system:serviceaccount:airflow:airflow-webserver",
  "system:serviceaccount:airflow:airflow-dag-processor",
  "system:serviceaccount:airflow:airflow-apiserver"  
 ]
}

resource "aws_iam_role_policy_attachment" "fargate_logs" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess" # 또는 최소 권한 정책
  role = module.eks.fargate_profiles["airflow_worker"].iam_role_name

}
# EC2 노드 그룹(웹 서버/API 서버)에도 S3 로그 정책 연결
resource "aws_iam_role_policy_attachment" "node_group_s3_logs" {
  policy_arn = aws_iam_policy.airflow_s3_log_policy.arn
  role       = module.eks.eks_managed_node_groups["core"].iam_role_name # 본인의 노드 그룹 이름 확인
}

resource "aws_iam_policy" "airflow_s3_log_policy" {
  name        = "AirflowS3LogPolicy"
  description = "Policy for Airflow workers to access S3 logs"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation" # DK 안정성을 위해 추가 추천
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:s3:::eks-airflow-bucket",
          "arn:aws:s3:::eks-airflow-bucket/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = "sts:AssumeRole"
        Resource = "arn:aws:iam::730746842295:role/AirflowWorkerS3Role-eks-airflow-7z1"
      }
    ]
  })
}

# 정책을 실제 Role에 연결하는 리소스
resource "aws_iam_role_policy_attachment" "airflow_s3_logs_attach" {
  # 로그에서 확인된 Role 이름을 여기에 넣습니다.
  role = module.eks.fargate_profiles["airflow_worker"].iam_role_name
  policy_arn = aws_iam_policy.airflow_s3_log_policy.arn
}

# 1. IAM Role 생성 (워커용)
resource "aws_iam_role" "airflow_worker_s3_role" {
  name = "airflow-worker-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRoleWithWebIdentity"
      Effect = "Allow"
      Principal = {
        Federated = module.eks.oidc_provider_arn
      }
      Condition = {
        StringEquals = {
          "${module.eks.oidc_provider}:sub" = "system:serviceaccount:airflow:airflow-worker"
        }
      }
    }]
  })
}

# 2. 기존에 만드신 S3 정책을 이 Role에 연결
resource "aws_iam_role_policy_attachment" "attach_s3_policy" {
  role       = aws_iam_role.airflow_worker_s3_role.name
  policy_arn = aws_iam_policy.airflow_s3_log_policy.arn
}

# AirflowWorkerS3Role 등에 아래 정책을 추가로 연결하세요.
resource "aws_iam_policy" "airflow_cloudwatch_policy" {
  name = "AirflowCloudWatchLogPolicy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams",
        "logs:CreateLogStream",
        "logs:PutLogEvents", # 로그 쓰기 (워커용)
        "logs:GetLogEvents"   # 로그 읽기 (웹서버용)
      ]
      Resource = "arn:aws:logs:ap-northeast-2:730746842295:log-group:/aws/eks/airflow-logs:*"
    }]
  })
}