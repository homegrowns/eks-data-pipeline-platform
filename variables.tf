variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "airflow_rds_user" {
  description = "airflow db 유저입니다."
  default = "airflow"
  type        = string
}

variable "db_password" {
  description = "RDS의 비밀번호입니다"
  type        = string
  sensitive   = true # 테라폼 로그에 암호가 찍히지 않게 보호!
}

variable "instance_class" {
  default     = "db.t3.micro" # 값을 안 넣으면 이 값이 기본으로 사용됨
}