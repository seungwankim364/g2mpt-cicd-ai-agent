# DOC-17. Runbook Script Design

## 1. 목적

이 문서는 AI Agent가 참고하거나 운영자가 실행할 수 있는 alert-specific shell script 구조를 정의한다.

Runbook은 단순 설명 문서가 아니라, alert가 발생했을 때 어떤 정보를 수집하고 어떤 조치를 검토해야 하는지 정해둔 실행 가능한 대응 절차다.

## 2. Runbook 위치

추천 위치:

```text
scripts/runbooks/
  backend-high-error-rate.sh
  backend-high-latency.sh
  pod-restarting.sh
  db-connection-error.sh
  waf-blocked-request-spike.sh
```

## 3. Alert Mapping

`config/quality-gate/alert-mapping.yaml`에서 alert와 runbook을 연결한다.

```yaml
BackendHighErrorRate:
  runbook: scripts/runbooks/backend-high-error-rate.sh
  category: application
  recommendedActions:
    - rollback
    - manual_fix

BackendHighLatency:
  runbook: scripts/runbooks/backend-high-latency.sh
  category: application
  recommendedActions:
    - rollback
    - manual_fix

BackendPodRestarting:
  runbook: scripts/runbooks/pod-restarting.sh
  category: kubernetes
  recommendedActions:
    - rollback
    - manual_fix

BackendDBConnectionError:
  runbook: scripts/runbooks/db-connection-error.sh
  category: dependency
  recommendedActions:
    - manual_fix
    - dr
```

## 4. Runbook Script 공통 입력

모든 runbook script는 공통 환경 변수를 받는다.

```text
SERVICE_NAME
ENVIRONMENT
NAMESPACE
DEPLOYMENT_NAME
ARGOCD_APP
IMAGE_TAG
COMMIT_SHA
FAILED_AT
ATHENA_DATABASE
ATHENA_OUTPUT_S3
AWS_REGION
```

## 5. Runbook Script 공통 출력

각 script는 표준 출력 또는 JSON 파일로 결과를 남긴다.

추천 출력:

```text
runbook-output.json
```

예시:

```json
{
  "runbook": "backend-high-error-rate",
  "service": "backend-api",
  "environment": "prod",
  "checks": [
    {
      "name": "pod_status",
      "status": "ok",
      "summary": "All pods are running"
    },
    {
      "name": "recent_errors",
      "status": "failed",
      "summary": "DB connection timeout repeated 128 times"
    }
  ],
  "recommendedActionHint": "rollback"
}
```

## 6. 공통 Script Template

```bash
#!/usr/bin/env bash
set -euo pipefail

: "${SERVICE_NAME:?SERVICE_NAME is required}"
: "${ENVIRONMENT:?ENVIRONMENT is required}"
: "${NAMESPACE:?NAMESPACE is required}"
: "${DEPLOYMENT_NAME:?DEPLOYMENT_NAME is required}"
: "${FAILED_AT:?FAILED_AT is required}"

echo "Running runbook for ${SERVICE_NAME}/${ENVIRONMENT}"
echo "Failed at: ${FAILED_AT}"

kubectl get deployment "${DEPLOYMENT_NAME}" -n "${NAMESPACE}"
kubectl get pods -n "${NAMESPACE}" -l "app=${SERVICE_NAME}"
```

## 7. `backend-high-error-rate.sh`

### 목적

`BackendHighErrorRate` alert 발생 시 5xx 증가 원인을 빠르게 좁힌다.

### 수집 항목

```text
최근 배포 image tag
Pod 상태
최근 application error log
ALB 5xx 상위 path
DB timeout/error 패턴
최근 Argo CD revision
```

### 수행 명령 예시

```bash
kubectl get pods -n "$NAMESPACE" -l "app=$SERVICE_NAME"
kubectl logs -n "$NAMESPACE" deploy/"$DEPLOYMENT_NAME" --since=15m | grep -Ei "error|exception|timeout" | tail -n 100
argocd app get "$ARGOCD_APP"
argocd app history "$ARGOCD_APP"
```

### Athena Query 연결

```text
athena/queries/alb-5xx-errors.sql
athena/queries/application-error-patterns.sql
```

### 대응 후보

```text
새 배포 직후 특정 API 5xx 급증 -> rollback
환경 변수/secret 누락 -> manual fix
DB 장애 동반 -> manual fix 또는 DR 승인
```

## 8. `backend-high-latency.sh`

### 목적

`BackendHighLatency` alert 발생 시 latency 증가 원인을 확인한다.

### 수집 항목

```text
p95/p99 latency
상위 지연 API path
DB query timeout
외부 API timeout
CPU/Memory 사용량
SQS backlog
```

### 수행 명령 예시

```bash
kubectl top pod -n "$NAMESPACE"
kubectl logs -n "$NAMESPACE" deploy/"$DEPLOYMENT_NAME" --since=15m | grep -Ei "slow|timeout|latency" | tail -n 100
```

### Athena Query 연결

```text
athena/queries/api-latency-top-paths.sql
athena/queries/application-error-patterns.sql
```

## 9. `pod-restarting.sh`

### 목적

`BackendPodRestarting` alert 발생 시 pod restart 원인을 확인한다.

### 수집 항목

```text
CrashLoopBackOff 여부
OOMKilled 여부
Probe failure 여부
최근 container previous logs
Kubernetes event
```

### 수행 명령 예시

```bash
kubectl get pods -n "$NAMESPACE" -l "app=$SERVICE_NAME"
kubectl describe deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE"
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | tail -n 50

POD_NAME="$(kubectl get pods -n "$NAMESPACE" -l "app=$SERVICE_NAME" -o jsonpath='{.items[0].metadata.name}')"
kubectl logs -n "$NAMESPACE" "$POD_NAME" --previous --tail=100 || true
```

### 대응 후보

```text
새 이미지에서만 CrashLoopBackOff -> rollback
OOMKilled -> resource limit 조정 또는 manual fix
Probe failure -> probe 설정 또는 app startup 문제 확인
```

## 10. `db-connection-error.sh`

### 목적

`BackendDBConnectionError` alert 발생 시 DB 연결 문제를 확인한다.

### 수집 항목

```text
DB connection timeout 로그
DB host/secret/env 설정 변경 여부
connection pool 설정
최근 migration 변경
DB 장애 또는 failover 여부
```

### 수행 명령 예시

```bash
kubectl logs -n "$NAMESPACE" deploy/"$DEPLOYMENT_NAME" --since=15m | grep -Ei "db|database|connection|timeout" | tail -n 100
kubectl describe deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" | grep -Ei "DB_|DATABASE_|SPRING_DATASOURCE" || true
```

### 대응 후보

```text
secret/env 누락 -> manual fix
migration 문제 -> manual fix
DB 자체 장애 -> DR 승인 검토
새 배포 직후 connection timeout 급증 -> rollback 검토
```

## 11. `waf-blocked-request-spike.sh`

### 목적

WAF blocked request 증가 시 보안 이벤트 또는 잘못된 rule 적용 여부를 확인한다.

### 수집 항목

```text
Blocked request count
상위 source IP
상위 URI
triggered rule
CloudFront/ALB 연계 로그
```

### Athena Query 연결

```text
athena/queries/waf-blocked-requests.sql
athena/queries/cloudfront-5xx-errors.sql
```

### 대응 후보

```text
정상 사용자 차단 -> WAF rule manual fix
공격성 트래픽 증가 -> 보안 대응
서비스 장애 동반 -> DR 또는 traffic 우회 검토
```

## 12. AI Agent와의 연결

AI Agent는 runbook script 자체를 실행하거나, script 내용을 읽어서 대응 절차로 참고할 수 있다.

초기 MVP에서는 다음 방식을 추천한다.

```text
1. Lambda가 Athena summary 생성
2. AI Agent가 alert 이름을 기준으로 runbook script path를 찾음
3. AI Agent가 script 내용을 context로 읽음
4. AI Agent가 실행 명령, 수집 결과, Athena summary를 근거로 추천 생성
```

고도화 단계에서는 runbook script를 실제 실행하고 결과 JSON을 AI Agent 입력에 포함할 수 있다.

```text
runbook-output.json
  -> AI Agent input
  -> ai-recommendation.json
```

## 13. 보안 주의사항

```text
Runbook output에 secret 값을 출력하지 않는다.
kubectl describe 결과에서 민감 env가 노출되지 않도록 필터링한다.
Slack 메시지에 token, password, connection string을 포함하지 않는다.
AI Agent 입력에도 민감 정보를 넣지 않는다.
운영 변경 명령은 승인 없이 자동 실행하지 않는다.
```

