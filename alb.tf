module "alb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.30"

  role_name = "AWSLoadBalancerControllerRole"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "kubernetes_service_account_v1" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.alb_controller_irsa.iam_role_arn
    }
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"

    # 타임아웃 추가
  timeout = 600
  wait    = true

  # EKS가 먼저 만들어지고 나서 설치
  depends_on = [
    module.eks,
    module.alb_controller_irsa,
    kubernetes_service_account_v1.aws_load_balancer_controller
  ]

 set = [
    {
      name  = "clusterName"
      value = module.eks.cluster_name
    },

    {
      name  = "region"
      value = var.region
    },

    {
      name  = "vpcId"
      value = module.vpc.vpc_id
    },

    {
      name  = "nodeSelector.role"
      value = "airflow"
    },

    {
      name  = "serviceAccount.create"
      value = "false"
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    }
  ]
}