# DOC-32. GitHub Secrets and Runtime Values

이 문서는 실제 서비스를 연결하기 전에 GitHub Actions, AWS, Slack, Prometheus에 넣어야 하는 값을 정리한다.

실제 secret 값은 이 문서에 쓰지 않는다. 이 문서에는 secret 이름, 입력 위치, 사용 파일, 확인 방법만 기록한다.

## 1. 원칙

```text
secret 값은 repository에 commit하지 않는다.
secret 값은 work-log.md에 기록하지 않는다.
secret 값은 Slack 메시지나 GitHub Actions log에 출력하지 않는다.
GitHub Actions는 GitHub Secrets 또는 OIDC role을 사용한다.
AWS Lambda는 가능하면 AWS Secrets Manager에서 secret을 읽는다.
```

## 2. 현재 workflow가 실제로 읽는 값

현재 코드 기준으로 이 저장소의 Quality Gate가 직접 읽는 secret은 아래 3개다.

| Secret name | 필수 | 읽는 파일 | 사용 목적 |
| --- | --- | --- | --- |
| `PROMETHEUS_URL` | yes | `.github/workflows/quality-gate.yml`, `scripts/quality-gate/query-prometheus-alerts.sh`, `scripts/quality-gate/query-prometheus-metrics.sh` | Prometheus API 조회 |
| `SLACK_WEBHOOK_URL` | yes | `.github/workflows/quality-gate.yml`, `scripts/quality-gate/send-slack-first-alert.py`, `scripts/quality-gate/send-slack-deploy-success.py` | Slack `#cd-deploy-alarm` 알림 전송 |
| `AWS_ROLE_ARN` | yes | `.github/workflows/quality-gate.yml` | GitHub OIDC로 AWS role assume 후 EventBridge event 발행 |

`GITOPS_PAT`는 기존 `gympt-ops` app CI/CD가 GitOps values update를 수행할 때 사용하는 secret이다. 이 저장소는 기존 배포 앞단을 다시 수행하지 않으므로 `GITOPS_PAT`를 필수 secret으로 받지 않는다.

Slack 승인 후 자동 rollback도 이 저장소가 GitOps를 직접 수정하지 않는다. 기존 `GITOPS_PAT`가 있는 GitOps/gympt-ops 쪽 rollback workflow를 호출한다.

대체 방식:

| Secret name | 필수 | 읽는 위치 | 사용 목적 |
| --- | --- | --- | --- |
| `AWS_ACCESS_KEY_ID` | no | GitHub Actions AWS credential step 추가 시 | 장기 access key 방식 |
| `AWS_SECRET_ACCESS_KEY` | no | GitHub Actions AWS credential step 추가 시 | 장기 access key 방식 |

장기 access key 방식은 MVP 테스트 외에는 권장하지 않는다.

## 3. GitHub Secrets 입력 위치

GitHub repository에서 아래 경로로 이동한다.

```text
Repository
  -> Settings
  -> Secrets and variables
  -> Actions
  -> Repository secrets
  -> New repository secret
```

등록할 값:

```text
PROMETHEUS_URL
SLACK_WEBHOOK_URL
AWS_ROLE_ARN
GH_WORKFLOW_DISPATCH_TOKEN   # 기존 GitOps/gympt-ops rollback workflow 호출 시 필요
```

## 4. GitHub Variables 입력 위치

민감하지 않은 값은 GitHub Variables로 관리할 수 있다.

```text
Repository
  -> Settings
  -> Secrets and variables
  -> Actions
  -> Variables
  -> New repository variable
```

현재 workflow에는 아래 값이 코드에 고정되어 있다.

| Variable candidate | 현재 값 | 현재 위치 | 비고 |
| --- | --- | --- | --- |
| `AWS_REGION` | `ap-northeast-2` | `.github/workflows/quality-gate.yml` | 나중에 variable로 분리 가능 |
| `EVENT_BUS_NAME` | `cd-quality-gate-prod-bus` | `.github/workflows/quality-gate.yml` | Terraform output과 일치해야 함 |
| `SLACK_CHANNEL` | `#cd-deploy-alarm` | `.github/workflows/quality-gate.yml` | webhook 채널과 일치해야 함 |
| `GRAFANA_BASE_URL` | `https://grafana.g2mpt.com` | `.github/workflows/quality-gate.yml` step argument | dashboard link 생성 기준 |
| `GRAFANA_DASHBOARD_UID` | `api-latency` | `.github/workflows/quality-gate.yml` step argument | backend-api main dashboard |
| `ARGOCD_URL` | `https://argocd.g2mpt.com` | `.github/workflows/quality-gate.yml` | 1차 Slack 알림 Argo CD Application 링크 |
| `ARGOCD_APP` | `backend-api-prod` | `.github/workflows/quality-gate.yml` | 1차 Slack 알림 대상 Application |
| `GITOPS_REPO` | `hj-3/gympt-gitops` | 기존 gympt-ops app CI/CD | 이 저장소의 필수 runtime 값이 아님 |
| `GITHUB_TOKEN_SECRET_ARN` | unset | Terraform variable `github_token_secret_arn` | 승인 후 대상 GitHub workflow 자동 dispatch용 token secret |
| `ROLLBACK_WORKFLOW_REPO` | unset | Terraform variable `rollback_workflow_repo` | rollback 승인 시 dispatch할 repository |
| `DR_WORKFLOW_REPO` | unset | Terraform variable `dr_workflow_repo` | DR 승인 시 dispatch할 repository |
| `APP_DEPLOY_WORKFLOW_REPO` | `hj-3/gympt-app` | Terraform variable `app_deploy_workflow_repo` | 조치 후 처음부터 다시 실행할 app 배포 workflow repository |
| `APP_DEPLOY_WORKFLOW_FILE` | `backend-api-ci.yml` | Terraform variable `app_deploy_workflow_file` | 조치 후 다시 실행할 app 배포 workflow |
| `APP_DEPLOY_WORKFLOW_REF` | `main` | Terraform variable `app_deploy_workflow_ref` | app 배포 workflow 실행 branch/ref |

MVP에서는 코드에 고정된 값을 유지해도 된다. 여러 환경으로 확장할 때 GitHub Variables로 분리한다.

## 5. 실제 값 기입 체크리스트

실제 값은 아래 표의 `입력 완료`만 체크한다. 값 자체는 쓰지 않는다.

| 항목 | 입력 위치 | 입력 완료 | 확인 방법 |
| --- | --- | --- | --- |
| `PROMETHEUS_URL` | GitHub Repository Secret | no | self-hosted runner에서 `/api/v1/alerts` 응답 수신 |
| `SLACK_WEBHOOK_URL` | GitHub Repository Secret | no | `#cd-deploy-alarm`에 테스트 알림 도착 |
| `AWS_ROLE_ARN` | GitHub Repository Secret | no | `aws sts get-caller-identity` 성공 |
| `cd-quality-gate/slack/webhook-url` | AWS Secrets Manager | no | Lambda가 Slack 2차 알림 전송 |
| `cd-quality-gate/ai-agent/api-key` | AWS Secrets Manager | no | 외부 AI Agent endpoint 사용 시 인증 성공 |

## 6. `GITOPS_PAT`

상태:

```text
이 저장소의 필수 secret이 아니다.
기존 gympt-ops app CI/CD가 GitOps values update를 수행할 때 사용한다.
```

기존 gympt-ops 책임:

```text
app repository GitHub Actions
  -> ECR push
  -> pt-agent-gitops/gympt-gitops values-dev.yaml 또는 values-prod.yaml image tag update
  -> PR 또는 commit
  -> Argo CD automated sync
```

이 저장소 책임:

```text
post-deploy Quality Gate
Prometheus alert/metric check
Slack deploy/failure alert
EventBridge DeploymentFailed event
AI incident analysis
```

따라서 이 저장소에 넣을 GitHub Secret 목록에서 `GITOPS_PAT`는 제외한다.

참고:

```text
gympt-app CI workflow가 charts/<service>/values-prod.yaml의 .image.tag를 변경
PR 생성 없이 gympt-gitops main branch에 직접 commit/push
Argo CD Application의 syncPolicy.automated가 Git 변경을 감지해 자동 배포
```

나중에 이 저장소가 직접 배포 트리거까지 담당하도록 범위를 확장할 때만 `GITOPS_PAT` 또는 GitHub App/Deploy Key 방식을 다시 검토한다.

## 7. `PROMETHEUS_URL`

목적:

```text
Quality Gate가 Prometheus API를 호출해 alert와 metric을 조회한다.
```

현재 사용 파일:

```text
.github/workflows/quality-gate.yml
scripts/quality-gate/query-prometheus-alerts.sh
scripts/quality-gate/query-prometheus-metrics.sh
```

필요 API:

```text
GET /api/v1/alerts
GET /api/v1/query
```

값 형태 예시:

```text
https://prometheus.example.com
http://kube-prometheus-stack-prometheus.monitoring.svc:9090
```

중요 결정:

```text
GitHub-hosted runner에서 접근하려면 외부 접근 가능한 HTTPS endpoint가 필요하다.
cluster 내부 service URL은 GitHub-hosted runner에서 접근할 수 없다.
self-hosted runner를 EKS/VPC 내부에 둘 경우 내부 service URL 사용 가능성이 있다.
```

현재 gympt-ops 참고값:

```text
http://kube-prometheus-stack-prometheus.monitoring.svc:9090
```

이 값은 cluster 내부 주소다. 따라서 Quality Gate workflow는 EKS/VPC 내부 self-hosted runner에서 실행한다.

현재 workflow 기준:

```yaml
runs-on: [self-hosted, linux, eks]
```

확인 방법:

```bash
curl -fsS "$PROMETHEUS_URL/api/v1/alerts"
```

## 8. `SLACK_WEBHOOK_URL`

목적:

```text
Quality Gate 실패 1차 알림과 배포 완료 알림을 Slack으로 보낸다.
```

현재 사용 파일:

```text
.github/workflows/quality-gate.yml
scripts/quality-gate/send-slack-first-alert.py
scripts/quality-gate/send-slack-deploy-success.py
```

대상 채널:

```text
#cd-deploy-alarm
```

주의:

```text
Incoming webhook이 특정 채널에 고정되는 Slack 설정이면 webhook 생성 시 #cd-deploy-alarm을 선택한다.
webhook URL은 절대 문서, 코드, work-log에 기록하지 않는다.
```

확인 방법:

```text
quality-gate.yml을 workflow_dispatch로 실행
성공 case: 배포 완료 알림 수신
실패 case: CD 실패 1차 알림 수신
```

## 9. `AWS_ROLE_ARN`

목적:

```text
GitHub Actions가 AWS EventBridge에 DeploymentFailed 이벤트를 발행한다.
```

현재 사용 예정 파일:

```text
.github/workflows/quality-gate.yml
scripts/quality-gate/publish-eventbridge-event.sh
```

현재 `publish-eventbridge-event.sh`는 AWS CLI credential이 이미 설정되어 있다고 가정한다. 따라서 workflow에 AWS credential step을 추가해야 한다.

추가 예정 예시:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
    aws-region: ap-northeast-2
```

필요 권한:

```text
events:PutEvents
```

대상 bus:

```text
cd-quality-gate-prod-bus
```

확인 방법:

```bash
aws sts get-caller-identity
aws events put-events --entries file://deployment-failed-event.json
```

## 10. AWS Secrets Manager

Lambda가 사용할 secret은 GitHub Secrets가 아니라 AWS Secrets Manager에 둔다.

| Secret name | 사용 주체 | 목적 |
| --- | --- | --- |
| `cd-quality-gate/slack/webhook-url` | Lambda Orchestrator | AI 분석 완료 후 Slack 2차 알림 전송 |
| `cd-quality-gate/ai-agent/api-key` | Lambda Orchestrator | 외부 AI Agent endpoint 인증 |

Terraform은 secret container만 만들고, 실제 값은 별도로 주입한다.

값 주입 예시:

```bash
aws secretsmanager put-secret-value \
  --secret-id cd-quality-gate/slack/webhook-url \
  --secret-string '<real webhook url>'
```

주의:

```text
Terraform variable에 secret 원문을 넣지 않는다.
terraform.tfstate에 secret 원문이 남지 않게 한다.
```

## 11. Argo CD 인증

gympt-ops 기본 배포 경로는 Argo CD CLI 직접 sync가 아니라 GitOps push와 Argo CD automated sync다.

backend-api-prod Application 기준:

```text
repoURL: https://github.com/hj-3/gympt-gitops.git
targetRevision: main
path: charts/backend-api
valueFiles: values-prod.yaml
syncPolicy.automated.prune: true
syncPolicy.automated.selfHeal: true
```

따라서 현재 `cd.yml`은 `argocd app sync`를 직접 실행하지 않는다.

Quality Gate는 Argo CD가 자동 배포한 뒤 아래를 확인한다.

```text
kubectl rollout status deployment/backend-api-prod -n gympt-prod
Prometheus alert/metric 조회
```

## 12. GitOps 인증

GitOps 인증은 기존 `gympt-ops` app CI/CD 책임이다.

```text
pt-agent-app 또는 gympt-app workflow
  -> ECR image push
  -> GitOps values image tag update
  -> Argo CD automated sync
```

이 저장소는 GitOps repository에 push하지 않는다.

따라서 이 저장소의 GitHub Secrets에는 아래 값을 넣지 않는다.

```text
GITOPS_PAT
GITOPS_DEPLOY_KEY
GITOPS_APP_PRIVATE_KEY
```

나중에 이 저장소가 독립 배포 트리거까지 담당하도록 범위가 바뀌면 그때 GitOps 인증 방식을 다시 설계한다.

## 13. 환경별 값

현재 prod 기준 확정값:

| 항목 | 값 |
| --- | --- |
| service | `backend-api` |
| environment | `prod` |
| namespace | `gympt-prod` |
| deployment | `backend-api-prod` |
| Argo CD app | `backend-api-prod` |
| values file | `charts/backend-api/values-prod.yaml` |
| EventBridge bus | `cd-quality-gate-prod-bus` |
| Slack channel | `#cd-deploy-alarm` |
| AWS region | `ap-northeast-2` |
| Grafana base URL | `https://grafana.g2mpt.com` |
| Grafana dashboard UID | `api-latency` |

## 14. 적용 순서

실제 값은 아래 순서로 넣는다.

```text
1. Slack #cd-deploy-alarm 채널 생성
2. Slack incoming webhook 생성
3. GitHub Secret SLACK_WEBHOOK_URL 등록
4. self-hosted runner를 EKS/VPC 내부에 준비
5. GitHub Secret PROMETHEUS_URL 등록
6. AWS OIDC role 생성
7. GitHub Secret AWS_ROLE_ARN 등록
8. Terraform으로 EventBridge/Lambda/S3/Athena 생성
9. AWS Secrets Manager에 Lambda용 Slack/AI secret 값 주입
10. 기존 gympt-ops 배포 완료 후 quality-gate.yml workflow_dispatch로 먼저 테스트
11. 기존 gympt-ops workflow에서 Quality Gate 호출 방식 연결
```

## 15. 실제 연결 전 체크

```text
GitHub Secrets에 값이 들어갔는가
Slack webhook URL이 #cd-deploy-alarm으로 연결되는가
PROMETHEUS_URL이 self-hosted runner에서 접근 가능한가
Argo CD backend-api-prod Application의 automated sync가 켜져 있는가
AWS_ROLE_ARN이 events:PutEvents 권한을 갖는가
EventBridge bus 이름이 Terraform output과 workflow 값이 일치하는가
Lambda에서 Secrets Manager secret을 읽을 권한이 있는가
workflow log에 secret 원문이 출력되지 않는가
```

## 16. 아직 결정해야 하는 것

| 항목 | 선택지 | 현재 상태 |
| --- | --- | --- |
| Prometheus 접근 방식 | EKS/VPC 내부 self-hosted runner | gympt-ops 방식으로 확정 |
| GitOps push 인증 | 기존 gympt-ops app CI/CD가 담당 | 이 저장소 범위 아님 |
| Argo CD sync 방식 | 기존 GitOps push 후 automated sync | gympt-ops 방식 사용 |
| AWS 인증 | GitHub OIDC 권장 | `AWS_ROLE_ARN` 필요 |
| Lambda Slack secret 전달 | Secrets Manager 권장 | Terraform secret container 있음 |

남은 것은 실제 secret 값을 넣고 self-hosted runner label을 준비한 뒤, 기존 gympt-ops 배포 완료 후 Quality Gate dry-run을 실행하는 것이다.
