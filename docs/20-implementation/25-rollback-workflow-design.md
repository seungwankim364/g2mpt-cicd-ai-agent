# DOC-27. Rollback Workflow Design

## 1. 목적

Slack 승인 이후 rollback을 실행하고, rollback 결과를 다시 Quality Gate로 검증하는 workflow를 설계한다.

## 2. 원칙

```text
AI Agent는 rollback을 직접 실행하지 않음
운영자 승인 이후에만 rollback 실행
rollback 후 반드시 Quality Gate 재검증
모든 승인과 실행 결과를 audit trail로 저장
```

## 3. Rollback Trigger

Rollback은 다음 경로로 시작된다.

```text
Slack 2차 알림
  -> Approve Rollback button
  -> Slack interaction endpoint
  -> Rollback workflow dispatch
```

MVP에서는 Slack button 대신 수동 `workflow_dispatch`로 대체할 수 있다.

## 4. 입력 값

```text
deploymentId
service
environment
currentImageTag
rollbackImageTag
argocdApp
approvedBy
approvalTimestamp
reason
```

예시:

```json
{
  "deploymentId": "deploy-20260609-001",
  "service": "backend-api",
  "environment": "prod",
  "currentImageTag": "backend-api:abc1234",
  "rollbackImageTag": "backend-api:def5678",
  "argocdApp": "backend-api-prod",
  "approvedBy": "ops-user",
  "reason": "BackendHighErrorRate after deployment"
}
```

## 5. GitOps Rollback 방식

권장 방식은 GitOps repository의 image tag를 이전 버전으로 되돌리는 것이다.

```text
1. rollback 대상 image tag 확인
2. GitOps repository checkout
3. service manifest 또는 values 파일 수정
4. rollback commit 생성
5. push
6. Argo CD sync
```

장점:

```text
변경 이력이 Git에 남음
Argo CD desired state와 일치
감사 추적이 쉬움
```

## 6. Argo CD Rollback 방식

대안으로 Argo CD revision rollback을 사용할 수 있다.

```text
argocd app rollback backend-api-prod <history-id>
```

이 방식은 빠르지만 GitOps repository와 desired state가 어긋날 수 있으므로 MVP에서는 GitOps image tag rollback을 우선한다.

## 7. Workflow 단계

```text
1. 승인 payload 검증
2. rollback 대상 image tag 확인
3. GitOps repository update
4. Argo CD sync
5. Argo CD app wait
6. Kubernetes rollout status 확인
7. Prometheus Quality Gate 재실행
8. Slack rollback 결과 알림
9. S3 status 업데이트
```

## 8. GitHub Actions Job 구조

```text
rollback.yml
  validate-approval
  request existing GitOps rollback change
  wait-argocd-automated-sync
  wait-rollout
  run-quality-gate
  notify-result
```

## 9. 실패 처리

| 단계 | 실패 시 처리 |
| --- | --- |
| 승인 검증 실패 | rollback 중단, Slack 알림 |
| GitOps 수정 실패 | rollback 중단, 수동 조치 요청 |
| Argo CD sync 실패 | Argo CD 링크 포함해 Slack 알림 |
| rollout 실패 | rollback 실패로 표시, 수동 확인 |
| Quality Gate 실패 | rollback 이후에도 장애 지속으로 표시 |
| Slack 알림 실패 | workflow log와 S3 status에 기록 |

## 10. Rollback 결과 상태

```text
requested
approved
running
gitops_updated
argocd_synced
quality_gate_running
succeeded
failed
requires_manual_intervention
```

## 11. Slack 결과 메시지

성공 메시지 포함 항목:

```text
service
environment
deploymentId
rollbackImageTag
approvedBy
Quality Gate result
Grafana link
Argo CD link
```

실패 메시지 포함 항목:

```text
실패 단계
오류 요약
수동 조치 필요 여부
workflow run link
Argo CD link
```

## 12. Audit Trail

저장 위치:

```text
S3 deployment-failures/{environment}/{service}/{deploymentId}/rollback.json
GitHub Actions workflow run
Git commit history
Slack approval log
```

## 13. 검증 기준

```text
승인 없이 rollback workflow 실행 불가
rollback 대상 image tag가 명확히 기록됨
GitOps repository에 rollback commit이 남음
rollback 후 Quality Gate가 재실행됨
성공/실패 결과가 Slack으로 전송됨
```
