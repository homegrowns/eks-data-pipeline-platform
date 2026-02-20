module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "malware-cluster-vpc"

  cidr = "10.0.0.0/16"

# 3개 AZ 사용 고가용성 모범 사례(slice(..., 0, 3)으로 인덱스 0, 1, 2의 3개 AZ를 지정)
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  # 3개 AZ에 할당할 3개의 프라이빗 서브넷 CIDR 정의
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  
  # 3개 AZ에 할당할 3개의 퍼블릭 서브넷 CIDR 정의
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]


  enable_nat_gateway   = true # 프라이빗 서브넷의 외부 통신(이미지 Pull 등) 위해 NAT 사용
  single_nat_gateway   = true # 비용 절감용 NAT GW 1개 (가용성보단 비용 우선)

  enable_dns_support = true #이 설정은 VPC 내의 모든 인스턴스(Pod 포함)가 AWS DNS 서버를 사용할 수 있도록 허용하는 가장 기본적인 설정입니다.
  enable_dns_hostnames = true #이 설정은 VPC 내의 EC2 인스턴스에 AWS가 제공하는 DNS 호스트 이름을 자동으로 할당하도록 허용합니다.

  # ALB/NLB가 퍼블릭 서브넷을 인식하도록 붙이는 표준 태그
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
  # 내부용 LoadBalancer는 프라이빗 서브넷 사용
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }

}

# 1. S3 (Gateway Endpoint)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = module.vpc.vpc_id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = module.vpc.private_route_table_ids # 모듈이 생성한 프라이빗 라우팅 테이블 ID 목록을 참조합니다.
}

# 2. ECR (Interface Endpoint - Docker Pull)
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id             = module.vpc.vpc_id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [aws_security_group.vpc_endpoint_sg.id]
  # private_dns_enabled: ECR의 퍼블릭 DNS 이름(예: <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com)을
  # 프라이빗 IP 주소로 해석할 수 있도록 설정합니다. (필수)
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id             = module.vpc.vpc_id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "sts_endpoint" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.sts"
  vpc_endpoint_type = "Interface"

  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [aws_security_group.vpc_endpoint_sg.id]

  private_dns_enabled = true

  tags = {
    Name = "sts-interface-endpoint"
  }
}

resource "aws_vpc_endpoint" "ec2_api_endpoint" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.ec2"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets 

  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id] 
  
  private_dns_enabled = true 

  tags = {
    Name = "ec2-api-interface-endpoint"
  }
}

# 7. CloudWatch Logs 엔드포인트 (CWL)
# EKS 노드/컨테이너 로그를 CloudWatch로 전송하는 데 필요합니다.
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  private_dns_enabled = true
}