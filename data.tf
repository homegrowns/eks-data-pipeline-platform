# 관리형 노드그룹이 아직 지원하지 않는 Local Zone 제외용 필터
#Terraform이 그 리전에 사용 가능한 AZ 목록을 AWS에서 조회해서 자동으로 선택
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"] # 누구나 사용 가능한 AZ만 선택
  }
}
# data aws_iam_policy는 권한 레시피를 조회
data "aws_iam_policy" "ebs_csi_policy" {
    arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
    #AmazonEBSCSIDriverPolicy = Amazon Amazon EKS 클러스터 내의 awsEBS CSI(Container Storage Interface) 드라이버가 
    # 사용자를 대신하여 AWS API 호출을 수행하는 데 필요한 권한을 부여
}

# data "aws_iam_policy" "ebs_csi_policy" {
#     arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess" # 또는 최소 권한 정책
# }

data "aws_region" "current" {
  # 현재 Terraform을 실행하는 AWS 리전을 자동으로 가져옵니다.
}