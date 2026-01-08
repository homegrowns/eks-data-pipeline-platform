# 2. RDS 서브넷 그룹 (DB가 배치될 서브넷 지정)
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "airflow-rds-subnet-group"
  subnet_ids = module.vpc.private_subnets 

  tags = {
    Name = "Airflow RDS Subnet Group"
  }
}

# 3. RDS 인스턴스 설정
resource "aws_db_instance" "airflow_db" {
  identifier           = "airflow-metastore"
  allocated_storage    = 20
  storage_type         = "gp3"
  engine               = "postgres"
  engine_version       = "15.15"
  instance_class       = "db.t3.micro" # 테스트용이므로 낮은 사양 선택
  
  db_name              = "airflow"
  username             = var.airflow_rds_user
  password             = var.db_password 
  
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  
  skip_final_snapshot  = true  # 테스트 단계에서 삭제 시 스냅샷 생략
  publicly_accessible  = false # 외부 노출 차단 (보안)
  multi_az             = false # 고가용성이 필요하면 true (비용 증가)

  tags = {
    Name = "Airflow-Metastore"
  }
}