#!/bin/bash

# 로그 파일 설정
LOG_FILE="cleanup_log_$(date +%Y%m%d).txt"

# 로그 기록 함수
log() {
  local MESSAGE="[$(date +'%Y-%m-%d %H:%M:%S')] $1"
  echo "$MESSAGE"
  echo "$MESSAGE" >> "$LOG_FILE"
}

if [ -z "$CLUSTER_NAME" ]; then
  log "ERROR: CLUSTER_NAME must be set"
  exit 1
fi

ARN_CONTEXT=$(kubectl config get-contexts -o name | grep "$CLUSTER_NAME" || true)

if [ -n "$ARN_CONTEXT" ]; then
  log "Deleting kubeconfig entries for: $ARN_CONTEXT"
  
  # 명령어 실행 및 결과를 로그에 기록
  kubectl config delete-context "$ARN_CONTEXT" >> "$LOG_FILE" 2>&1
  kubectl config delete-cluster "$ARN_CONTEXT" >> "$LOG_FILE" 2>&1
  kubectl config delete-user "$ARN_CONTEXT" >> "$LOG_FILE" 2>&1
  
  log "SUCCESS: Cleanup completed for $CLUSTER_NAME"
else
  log "INFO: No matching context found for $CLUSTER_NAME"
fi

log "-------------------------------------------"