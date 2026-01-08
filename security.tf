# VPC Endpoint 전용 보안 그룹 생성
resource "aws_security_group" "vpc_endpoint_sg" {
  name        = "vpc-endpoint-sg"
  description = "Security group for VPC Endpoints (ECR, Glue, CWL, etc.)"
  vpc_id      = module.vpc.vpc_id # VPC 모듈의 출력값 사용

  # 인바운드 규칙: Airflow 컴포넌트가 Endpoint에 접근할 수 있도록 허용
  # Airflow 컴포넌트가 모두 프라이빗 서브넷에 있으므로, VPC CIDR 전체를 허용합니다.
  # 더 엄격하게 하려면 Airflow 컴포넌트 SG의 ID를 source_security_group_id로 사용합니다.

  #인바운드 (Inbound) 규칙: 외부에서 보안 그룹이 적용된 리소스(VPC Endpoint ENI)로 들어오는 트래픽을 제어합니다.
  ingress {
    description = "Allow inbound HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block] # VPC 전체 CIDR 블록 (예: 10.0.0.0/16)
  }

  # 아웃바운드 규칙: 기본적으로 모두 허용
  #아웃바운드 (Outbound) 규칙: 보안 그룹이 적용된 리소스에서 외부로 나가는 트래픽을 제어합니다.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "sg-ec2-api-endpoint"
  }
}

# RDS(PostgreSQL) 전용 보안 그룹
resource "aws_security_group" "rds_sg" {
  name        = "airflow-rds-sg"
  description = "Security group for Airflow RDS (PostgreSQL)"
  vpc_id      = module.vpc.vpc_id 

  ingress {
    description = "Allow PostgreSQL inbound from VPC CIDR"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block] # VPC 내부 어디서든 DB 접속 허용
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-airflow-rds"
  }
}

# Fargate -> CoreDNS (EC2) 질문 허용 (UDP 53)
resource "aws_security_group_rule" "fargate_to_coredns_udp" {
  description              = "Allow Fargate workers to query CoreDNS on EC2 nodes (UDP)"
  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "udp"
  security_group_id        = module.eks.node_security_group_id # EC2 노드 보안 그룹
  source_security_group_id = module.eks.cluster_primary_security_group_id # Fargate가 사용하는 보안 그룹
}

# Fargate -> CoreDNS (EC2) 질문 허용 (TCP 53)
resource "aws_security_group_rule" "fargate_to_coredns_tcp" {
  description              = "Allow Fargate workers to query CoreDNS on EC2 nodes (TCP)"
  type                     = "ingress"
  from_port                = 53
  to_port                  = 53
  protocol                 = "tcp"
  security_group_id        = module.eks.node_security_group_id
  source_security_group_id = module.eks.cluster_primary_security_group_id
}

# Airflow API 서버가 워커의 요청(8080 포트)을 받을 수 있도록 허용
resource "aws_security_group_rule" "api_server_ingress_from_worker" {
  description              = "Allow Airflow Worker to connect to API Server"
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  # API 서버가 속한 보안 그룹 ID (보통 node_security_group_id 또는 별도 SG)
  security_group_id        = module.eks.node_security_group_id 
  # 요청을 보내는 워커(Fargate)의 보안 그룹 ID
  source_security_group_id = module.eks.cluster_primary_security_group_id 
}

resource "aws_security_group_rule" "fargate_s3_egress" {
# TODO:aws_security_group.your_fargate_sg.id #fargate id찾아서 넣기
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = module.eks.cluster_primary_security_group_id  #실제 사용 중인 Fargate 보안 그룹 ID
  cidr_blocks       = ["0.0.0.0/0"]          # S3 게이트웨이는 0.0.0.0/0 허용 필요
  description       = "Allow Fargate pods to reach S3 via HTTPS"
}

# EKS 컨트롤 플레인이 Fargate로부터 오는 신호를 받을 수 있도록 허용 (Inbound)
resource "aws_security_group_rule" "eks_allow_fargate_inbound" {
  description              = "Allow Fargate workers to communicate with the cluster API Server"
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  
  # 규칙을 적용할 대상: EKS 컨트롤 플레인의 보안 그룹
  security_group_id        = module.eks.cluster_primary_security_group_id
  
  # 허용해줄 출발지: VPC 내부 전체 혹은 Fargate가 속한 서브넷 대역
  # 더 보안을 강화하려면 Fargate 전용 SG ID를 별도로 지정할 수도 있습니다.
  cidr_blocks              = [module.vpc.vpc_cidr_block] 
}

# (필요 시) API 서버가 Fargate Pod에게 명령을 내릴 수 있도록 허용 (Egress/Ingress)
# 보통 모듈에서 자동으로 처리하지만, 통신이 확실히 안 된다면 아래 규칙도 체크
resource "aws_security_group_rule" "fargate_allow_api_inbound" {
  description              = "Allow API Server to communicate with Fargate Pods (for logs/exec)"
  type                     = "ingress"
  from_port                = 10250 # Kubelet 포트
  to_port                  = 10250
  protocol                 = "tcp"
  
  # 규칙을 적용할 대상: Fargate가 사용하는 보안 그룹 (없다면 클러스터 기본 SG)
  security_group_id        = module.eks.cluster_primary_security_group_id 
  
  # 출발지: API 서버(컨트롤 플레인)가 속한 SG
  source_security_group_id = module.eks.cluster_security_group_id
}
resource "aws_security_group_rule" "sts_endpoint_ingress_from_fargate" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.vpc_endpoint_sg.id # 엔드포인트 SG
  source_security_group_id = module.eks.cluster_primary_security_group_id # Fargate SG

  description              = "Allow HTTPS from Fargate to STS Endpoint"
}

resource "aws_security_group_rule" "fargate_worker_log_ingress_from_nodes" {
  description              = "Allow Webserver (EC2 Node) to fetch logs from Worker (Fargate)"
  type                     = "ingress"
  from_port                = 8793
  to_port                  = 8793
  protocol                 = "tcp"

  # Fargate 워커가 사용하는 보안 그룹 (보통 클러스터 기본 SG)
  security_group_id        = module.eks.cluster_primary_security_group_id

  # 웹 서버가 떠 있는 EC2 노드 그룹의 보안 그룹
  source_security_group_id = module.eks.node_security_group_id 
}

resource "aws_security_group_rule" "node_egress_to_fargate_worker" {
  description              = "Allow Webserver nodes to send requests to Fargate workers"
  type                     = "egress"
  from_port                = 8793
  to_port                  = 8793
  protocol                 = "tcp"

  # [대상] 웹 서버 노드 그룹 보안 그룹
  security_group_id        = module.eks.node_security_group_id

  # [목적지] Fargate 워커 보안 그룹
  source_security_group_id = module.eks.cluster_primary_security_group_id
}