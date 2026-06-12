# DOC-26. Operations Runbook

## 1. 목적

CD Quality Gate 실패 또는 AI Incident Analysis Pipeline 장애가 발생했을 때 운영자가 확인하고 조치할 순서를 정리한다.

## 2. 운영자가 보는 첫 신호

```text
Post-deploy Quality Gate job failed
Slack 1차 알림 수신
Slack 2차 AI 분석 알림 수신
Argo CD application degraded
Grafana alert firing
```

## 3. 배포 실패 1차 확인

확인 순서:

```text
1. Slack 1차 알림에서 service, environment, deploymentId 확인
2. GitHub Actions run link 확인
3. Argo CD application 상태 확인
4. Grafana dashboard에서 error rate/latency 확인
5. Prometheus firing alert 확인
```

판단 기준:

```text
rollout 실패면 Kubernetes/Argo CD 중심으로 확인
rollout 성공 후 metric 실패면 application/traffic 중심으로 확인
```

## 4. Slack 1차 알림 대응

Slack 1차 알림에 포함된 정보를 기준으로 초기 분류를 한다.

| 신호 | 우선 확인 |
| --- | --- |
| HighErrorRate | 최근 배포 변경, application error log, ALB 5xx |
| HighLatency | DB/API dependency, slow path, resource saturation |
| PodRestarting | container log, OOMKilled, readiness/liveness probe |
| DBConnectionError | DB endpoint, secret, connection pool |
| WAFBlockedRequestSpike | WAF rule, client IP, request path |

## 5. AI 분석 결과 확인

Slack 2차 알림에서 확인할 항목:

```text
summary
causeCandidates
confidence
recommendedAction
evidence
Grafana link
Athena summary link
Argo CD link
```

AI 추천은 최종 판단이 아니라 운영 판단을 돕는 근거로 사용한다.

## 6. Rollback 판단

Rollback을 우선 고려하는 조건:

```text
장애가 배포 직후 시작됨
error rate 또는 latency가 critical threshold 초과
영향 범위가 핵심 API 또는 전체 서비스
이전 버전에서는 동일 문제가 없었음
AI confidence가 high 또는 medium
```

Rollback보다 manual fix를 고려하는 조건:

```text
외부 dependency 장애
DB credential/config 문제
WAF rule 오탐
인프라 capacity 이슈
배포 변경과 직접 관련이 약함
```

## 7. Rollback 실행 전 체크

```text
현재 production 영향 확인
rollback 대상 image tag 확인
DB migration 호환성 확인
feature flag 영향 확인
승인자 확인
Slack approval 기록 확인
```

## 8. Rollback 후 확인

Rollback 이후 확인 순서:

```text
1. Argo CD sync 완료
2. Kubernetes rollout 완료
3. Pod restart 안정화
4. Prometheus alert resolved 확인
5. Grafana error rate/latency 정상화 확인
6. Slack에 rollback 결과 공유
```

## 9. AI 분석 파이프라인 장애 대응

### 9.1 EventBridge 이벤트 미발행

확인:

```text
GitHub Actions aws events put-events 결과
event bus name
event source/detail-type
AWS credential/OIDC 권한
```

### 9.2 Lambda 미실행

확인:

```text
EventBridge rule enabled 여부
Lambda target 연결
aws_lambda_permission 설정
CloudWatch invocation metric
```

### 9.3 Athena Query 실패

확인:

```text
Athena workgroup
S3 result location 권한
Glue table 존재 여부
SQL syntax
partition 조건
```

### 9.4 Slack 2차 알림 실패

확인:

```text
Slack webhook secret
message payload 크기
Lambda outbound network
Slack API 응답 코드
```

## 10. Incident 기록

남길 정보:

```text
deploymentId
service/environment
발생 시각
감지 alert
영향 범위
AI recommendation
실제 조치
복구 시각
follow-up item
```

## 11. 종료 기준

```text
alert resolved
error rate/latency 정상화
사용자 영향 종료
rollback 또는 fix 결과 확인
Slack에 종료 공지
postmortem 필요 여부 결정
```

## 12. 퇴근 전 비용 절감 절차

이 프로젝트에서 Terraform으로 만든 AWS 리소스는 Lambda, EventBridge, API Gateway, Athena, S3처럼 stop 개념이 없는 serverless 관리 리소스가 중심이다. 퇴근 전 비용 정리는 stop/scale down이 아니라 Terraform stack destroy를 기준으로 한다.

사용 스크립트:

```text
scripts/aws/destroy-terraform-stack.sh
```

기본 실행은 dry-run이며 destroy plan만 확인한다.

```bash
AWS_PROFILE_NAME=ksw2 \
AWS_REGION=ap-northeast-2 \
ENVIRONMENT=prod \
scripts/aws/destroy-terraform-stack.sh
```

실제로 삭제하려면 `ALLOW_PROD=true`와 `--execute`를 함께 붙인다.

```bash
AWS_PROFILE_NAME=ksw2 \
AWS_REGION=ap-northeast-2 \
ENVIRONMENT=prod \
ALLOW_PROD=true \
scripts/aws/destroy-terraform-stack.sh --execute
```

삭제 대상 리소스:

```text
Terraform state에 있는 cd-quality-gate-architecture stack 리소스
Lambda
EventBridge
API Gateway
Athena
S3 result bucket
IAM role/policy
```

주의사항:

```text
prod 환경 execute는 ALLOW_PROD=true 없이는 차단됨
기존 수동 생성 Slack webhook secret은 state에서 제거해 destroy 대상에서 제외함
기존 수동 생성 GitHub dispatch token secret은 Terraform state에 넣지 않음
gympt-ops 리소스는 Terraform state에 없으므로 destroy 대상이 아님
S3 result bucket은 destroy 전에 해당 bucket만 비움
```
