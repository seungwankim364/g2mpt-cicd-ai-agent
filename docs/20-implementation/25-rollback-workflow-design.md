# DOC-27. Rollback Workflow Design

## 1. 목적

Slack 승인 이후 rollback 요청을 기존 PAT가 있는 GitOps repository workflow로 전달하고, GitOps repository 안에서 Helm values image tag를 이전 tag로 되돌리는 workflow를 설계한다.

## 2. 원칙

```text
AI Agent는 rollback을 직접 실행하지 않음
운영자 승인 이후에만 rollback 실행
rollback은 기존 PAT가 있는 gympt-gitops workflow에서 GitOps values image tag rollback commit으로 수행
rollback 후 Quality Gate 재검증은 Argo CD sync 이후 후속 workflow에서 수행
모든 승인과 실행 결과를 audit trail로 저장
```

## 3. Rollback Trigger

Rollback은 다음 경로로 시작된다.

```text
Slack 2차 알림
  -> Approve Rollback button
  -> Slack interaction endpoint
  -> slack-approval-handler Lambda
  -> DeploymentActionApproved EventBridge event
  -> deployment-action-executor Lambda
  -> Rollback workflow dispatch
```

현재 구현된 자동 승인 흐름은 아래와 같다.

```text
Slack Approve button
  -> API Gateway POST /slack/interactions
  -> lambda/slack-approval-handler/app.py
  -> DeploymentActionApproved EventBridge 이벤트 발행
  -> lambda/deployment-action-executor/app.py
  -> action type에 맞는 GitHub Actions workflow 자동 dispatch
```

수동 `approved-action.yml`은 장애 상황에서 Slack interactivity를 우회하기 위한 보조 경로로만 사용한다.

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
3. gympt-gitops rollback workflow dispatch
4. rollback request artifact 저장
5. gympt-gitops workflow가 values-prod.yaml image.tag rollback commit 생성
6. Argo CD가 GitOps 변경을 감지해 EKS에 sync
7. rollout과 Quality Gate 재검증 수행
8. 결과 Slack 알림과 S3 status 업데이트
```

## 8. GitHub Actions Job 구조

```text
rollback.yml
  validate-approval
  dispatch gympt-gitops rollback workflow
  dispatch gympt-app deployment workflow from beginning
  upload rollback request artifact
```

현재 MVP workflow:

```text
slack-approval-handler
  verify Slack signature
  parse approved action
  publish DeploymentActionApproved

deployment-action-executor
  read DeploymentActionApproved
  dispatch rollback/dr/manual_fix/change workflow by action type
```

실제 rollback 실행은 기존 PAT가 있는 `hj-3/gympt-gitops` workflow가 수행한다. 이 repo의 `rollback.yml`은 대상 workflow를 dispatch하는 wrapper다. DR 실행은 아직 대상 repo에 DR workflow가 없다면 새 workflow를 만들거나 이 repo의 `dr-failover.yml`에 실제 DR 명령을 연결해야 한다. 대상 workflow repository는 Terraform 변수 `rollback_workflow_repo`, `dr_workflow_repo`, `manual_fix_workflow_repo`, `change_workflow_repo`로 지정한다.

조치 workflow가 끝나면 `app_repo`, `app_workflow`, `app_ref` 입력값으로 기존 `gympt-app` 배포 workflow를 다시 dispatch한다. 이 app workflow가 build/test, ECR push, GitOps values update, Argo CD sync를 수행하고 마지막에 `quality-gate.yml`을 호출해야 Slack 배포 완료 알림까지 이어진다.

현재 이 repo에 생성된 실행 workflow:

```text
.github/workflows/rollback.yml
.github/workflows/dr-failover.yml
.github/workflows/manual-fix.yml
.github/workflows/change-apply.yml
```

`gympt-gitops/.github/workflows/rollback.yml`을 추가했다. 이 workflow는 `workflow_dispatch` 전용이며, `gympt-gitops` repo 안의 기존 `GITOPS_PAT`를 사용해 `charts/backend-api/values-prod.yaml`의 `image.tag`를 이전 tag로 갱신한다.
`dr-failover.yml`은 아직 Route53, CloudFront, ALB, EKS 같은 운영 리소스를 직접 변경하지 않는다. 기존 AWS/GitOps 권한이 있는 대상 workflow를 새로 만들거나, 이 repo workflow에 실제 DR 명령을 연결해야 한다.

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
gympt-gitops rollback workflow가 dispatch됨
GitOps repository rollback commit이 생성됨
Argo CD가 rollback tag를 기준으로 sync함
rollback 후 Quality Gate 재검증 흐름이 추적됨
성공/실패 결과가 Slack 또는 workflow artifact로 남음
```
