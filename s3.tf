# # 1. 버킷은 껍데기만 만듭니다.
# resource "aws_s3_bucket" "tfstate" {
#   bucket = "eks-airflow-bucket"

# # 실수로 terraform apply 시 삭제되는 것을 막아줍니다.
#   lifecycle {
#     prevent_destroy = false
#   }
  
# }

# # 2. 버전 관리(Versioning) 설정을 별도 리소스로 연결합니다.
# resource "aws_s3_bucket_versioning" "tfstate" {
#   bucket = aws_s3_bucket.tfstate.id # 위에서 만든 버킷 ID 참조

#   versioning_configuration {
#     status = "Enabled"
#   }
# }


# resource "aws_dynamodb_table" "terraform_lock" {
#   # 1. s3 backend 설정에 적은 이름과 똑같아야 합니다.
#   name = "eks-airflow-terraform-lock"

#   # 2. 요금 모드: State Locking은 사용량이 적으므로 '요청당 지불'이 훨씬 저렴합니다.
#   billing_mode = "PAY_PER_REQUEST"

#   # 3. 해시 키(PK): Terraform 규칙상 무조건 "LockID"여야 합니다. (대소문자 주의)
#   hash_key = "LockID"

#   # 4. 속성 정의
#   attribute {
#     name = "LockID"
#     type = "S" # String 타입
#   }

#   tags = {
#     Name        = "terraform-lock-table"
#     Environment = "production"
#   }
# }