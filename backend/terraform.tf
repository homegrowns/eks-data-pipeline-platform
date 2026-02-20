terraform {

  required_version = "~> 1.3"
  # cloud {
  #   workspaces {
  #     name = "learn-terraform-eks"
  #   }
  # }
    backend "s3" {
    bucket         = "malware-project-bucket"
    key            = "terraform/malware/terraform.tfstate"
    region         = "ap-northeast-2"
    use_lockfile   = true
    dynamodb_table = "malware-terraform-lock"
  }
}

# 1.terraform init (backend "s3"  주석처리후 실행)
# 2.terraform apply  # -> 여기서 S3와 DynamoDB가 실제로 생성됨
# 3.terraform init (backend "s3"  주석제거후 실행)