
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
module "irsa-airflow" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.39.0"

  create_role  = true
  role_name    = "AirflowS3Role-${module.eks.cluster_name}"
  provider_url = module.eks.oidc_provider

  role_policy_arns = [aws_iam_policy.airflow_s3_log_policy.arn,
                     aws_iam_policy.airflow_s3_zeek_read_policy.arn]

  oidc_fully_qualified_subjects = [
    "system:serviceaccount:airflow:airflow-api-server",
    "system:serviceaccount:airflow:airflow-scheduler",
    "system:serviceaccount:airflow:airflow-triggerer",
    "system:serviceaccount:airflow:airflow-worker",
    "system:serviceaccount:airflow:airflow-dag-processor"
  ]
}



resource "aws_iam_policy" "airflow_s3_log_policy" {
  name = "AirflowS3LogPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListBucketLogsPrefix"
        Effect = "Allow"
        Action = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::malware-project-bucket"
        Condition = {
          StringLike = { "s3:prefix" = ["airflow-logs/*"] }
        }
      },
      {
        Sid    = "RWLogsObjects"
        Effect = "Allow"
        Action = ["s3:GetObject","s3:PutObject","s3:DeleteObject"]
        Resource = "arn:aws:s3:::malware-project-bucket/airflow-logs/*"
      },
      {
        Sid    = "GetBucketLocation"
        Effect = "Allow"
        Action = ["s3:GetBucketLocation"]
        Resource = "arn:aws:s3:::malware-project-bucket"
      }
    ]
  })
}

resource "aws_iam_policy" "airflow_s3_zeek_read_policy" {
  name = "AirflowS3ZeekReadPolicy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid: "ListBucketZeekHttpPrefix",
        Effect: "Allow",
        Action: ["s3:ListBucket"],
        Resource: "arn:aws:s3:::malware-project-bucket",
        Condition: {
          StringLike: {
            "s3:prefix": [
            "honeypot/raw/zeek/http/*",
            "honeypot/raw/zeek/dns/*",
            "honeypot/raw/zeek/conn/*"
            ]
          }
        }
      },
      {
        Sid: "GetZeekHttpObjects",
        Effect: "Allow",
        Action: ["s3:GetObject","s3:GetObjectVersion"],
        Resource: [
                  "arn:aws:s3:::malware-project-bucket/honeypot/raw/zeek/http/*",
                  "arn:aws:s3:::malware-project-bucket/honeypot/raw/zeek/dns/*",
                  "arn:aws:s3:::malware-project-bucket/honeypot/raw/zeek/conn/*"]
      }
    ]
  })
}


# AirflowWorkerS3Role 등에 아래 정책을 추가로 연결하세요.
# resource "aws_iam_policy" "airflow_cloudwatch_policy" {f
#   name = "AirflowCloudWatchLogPolicy"
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#       Action = [
#         "logs:DescribeLogGroups",
#         "logs:DescribeLogStreams",
#         "logs:CreateLogStream",
#         "logs:PutLogEvents", # 로그 쓰기 (워커용)
#         "logs:GetLogEvents"   # 로그 읽기 (웹서버용)
#       ]
#       Resource = "arn:aws:logs:ap-northeast-2:730746842295:log-group:/aws/eks/airflow-logs:*"
#     }]
#   })
# }