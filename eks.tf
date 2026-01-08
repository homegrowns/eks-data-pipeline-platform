module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.5"

  cluster_name    = local.cluster_name
  cluster_version = "1.30"

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access = true # 퍼블릭 접근 허용
  cluster_endpoint_public_access_cidrs = [
    "1.234.184.156/32", # 예: "203.0.113.42/32"
    "112.172.181.110/32"
  ]
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
    }
  }
  
  enable_irsa = true
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnets 

eks_managed_node_groups = {
    # Core 그룹: 스케줄러와 웹서버가 살 곳 (안정성 중요!)
    core = {
      name = "airflow-core"
      
      # 스케줄러는 끊기면 안됨 안정적인 온디맨드(기본값) 사용
      capacity_type  = "SPOT"#"ON_DEMAND" 
      instance_types = ["t3.medium"]
      ami_type = "AL2023_x86_64_STANDARD"

      min_size     = 2
      max_size     = 3
      desired_size = 2

      # 노드 그룹이 프라이빗 서브넷에 생성되도록 명시
      subnet_ids     = module.vpc.private_subnets
      
      # 나중에 Airflow 헬름 차트에서 nodeSelector로 이 라벨을 찾게 함
      labels = {
        role = "core"
      }
    }
  }

  fargate_profiles = {
  # 핵심 Profile: Airflow Worker용
  airflow_worker = {
    name = "airflow-worker"
    
    selectors = [
      {
        namespace = "airflow" # Airflow가 배포된 네임스페이스 (Helm 기본값)
        labels = {
          # Helm Chart의 values.yaml에서 worker Pod에 붙일 라벨
          # 예를 들어, airflow-worker Pod에 component: worker 라벨을 붙이도록 설정
          component = "worker" 
        }
      }
    ]
    # VPC Endpoint를 사용하기 위해 Private Subnet으로 지정
    subnet_ids = module.vpc.private_subnets 
    cluster_name = module.eks.cluster_name
  }

    alb_controller = {
      name = "alb-controller"
      selectors = [
        {
          namespace = "kube-system"
          labels = {
            "app.kubernetes.io/name" = "aws-load-balancer-controller"
          }
        }
      ]
      subnet_ids = module.vpc.private_subnets
    }

}
}

resource "null_resource" "update_kubeconfig" {
  triggers = {
    cluster_name = module.eks.cluster_name
    endpoint     = module.eks.cluster_endpoint
  }

  # terraform apply
  provisioner "local-exec" {
    when    = create
    command = "aws eks update-kubeconfig --name ${self.triggers.cluster_name} --region ap-northeast-2"
  }
  # terraform destroy
  provisioner "local-exec" {
    when    = destroy
    command = "CLUSTER_NAME=${self.triggers.cluster_name} ./cleanup.sh"
  }
}

resource "random_string" "suffix" {
  length  = 3
  special = false
}

locals {
  # 클러스터 이름에 랜덤 접미사 붙여 중복/충돌 방지
  cluster_name = "eks-airflow-${random_string.suffix.result}"
}