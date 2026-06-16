# Monitoring-driven CD Quality Gate with AI Incident Analysis

Prometheus 기반 CD 배포 검증과 AI 장애 분석 파이프라인을 설계하고 구현하기 위한 개인 파트 작업 공간이다.

## 한 줄 요약

배포가 끝났는지만 확인하는 CD가 아니라, 배포 이후 서비스가 실제로 정상인지 Prometheus/Grafana 기준으로 검증하고, 실패 시 Slack, EventBridge, Athena, AI Agent를 연결해 원인 후보와 조치 방향을 전달하는 구조를 만든다.

## 이 저장소의 역할

이 저장소는 실제 서비스 저장소가 아니라, `gympt-ops` 서비스에 나중에 붙일 CD Quality Gate 개인 파트를 설계하고 검증하는 공간이다.

```text
cd-quality-gate-architecture
  -> 개인 파트 설계 문서
  -> 샘플 workflow
  -> quality gate script
  -> 설정 예시
  -> 운영/비용 절감 스크립트

gympt-ops
  -> 실제 서비스 저장소
  -> 지금은 참고만 함
  -> 이 저장소에서 직접 수정하지 않음
```

즉, 여기서 충분히 설계하고 검증한 뒤 필요한 부분만 `gympt-ops`에 최소 변경으로 붙이는 방식이다.

## 핵심 흐름

```text
Existing gympt-ops CI/CD
  -> build/test/ECR push/GitOps values update
  -> Argo CD automated sync
  -> EKS rollout 완료
  -> cd-quality-gate-architecture extension 시작
  -> 5분 Health Check Window 동안 Prometheus alert/metric 조회
  -> Quality Gate 판단
  -> 정상: CD 성공
  -> 실패: CD 실패 + Slack 1차 알림
  -> EventBridge DeploymentFailed 이벤트
  -> Lambda Orchestrator
  -> Athena 로그 분석
  -> Amazon Bedrock 기반 AI 원인 분석
  -> Slack 2차 알림
  -> 운영자 승인 기반 rollback 또는 manual fix
```

## 현재 구현 상태

`docs/10-architecture`와 `docs/20-implementation/14-implementation-file-architecture.md` 기준으로 실제 구현 scaffold를 채워둔 상태다. AWS, Slack, 내부 Prometheus는 실제 값을 넣기 전에도 fixture와 dry-run으로 흐름을 확인할 수 있다.

| 구분 | 위치 | 설명 |
| --- | --- | --- |
| Post-deploy workflow | [.github/workflows/cd.yml](.github/workflows/cd.yml) | 기존 gympt-ops 배포 이후 Quality Gate 호출용 wrapper |
| Quality Gate workflow | [.github/workflows/quality-gate.yml](.github/workflows/quality-gate.yml) | Prometheus 조회, Gate 판단, Slack/EventBridge 연동 |
| 샘플 workflow | [.github/workflows/cd-quality-gate-sample.yml](.github/workflows/cd-quality-gate-sample.yml) | fixture 기반 Quality Gate 실행 예시 |
| CD 보조 스크립트 | [scripts/cd](scripts/cd) | rollout 확인, 선택적 GitOps/Argo CD 수동 운영 보조 도구 |
| 서비스 설정 | [config/services/backend-api.yaml](config/services/backend-api.yaml) | backend-api 기준 서비스 설정 |
| Quality Gate 설정 | [config/quality-gate](config/quality-gate) | threshold, alert mapping, Grafana dashboard 설정 |
| Health Check Window | [scripts/quality-gate/run-health-check-window.sh](scripts/quality-gate/run-health-check-window.sh) | 기본 5분 동안 60초 간격으로 Prometheus alert/metric을 반복 조회하고 최종 Gate 결과 집계 |
| Prometheus 조회 | [scripts/quality-gate/query-prometheus-alerts.sh](scripts/quality-gate/query-prometheus-alerts.sh) | Prometheus alert 조회 또는 fixture 사용 |
| Gate 판단 | [scripts/quality-gate/evaluate-quality-gate.py](scripts/quality-gate/evaluate-quality-gate.py) | firing alert 기반 pass/fail 판단 |
| Grafana 링크 | [scripts/quality-gate/build-grafana-links.py](scripts/quality-gate/build-grafana-links.py) | Slack에 넣을 dashboard 링크 생성 |
| Slack 1차 알림 | [scripts/quality-gate/send-slack-first-alert.py](scripts/quality-gate/send-slack-first-alert.py) | 실패 알림 payload 생성 또는 전송 |
| Slack 배포 완료 알림 | [scripts/quality-gate/send-slack-deploy-success.py](scripts/quality-gate/send-slack-deploy-success.py) | Quality Gate 통과 후 배포 완료 payload 생성 또는 전송 |
| EventBridge 발행 | [scripts/quality-gate/publish-eventbridge-event.sh](scripts/quality-gate/publish-eventbridge-event.sh) | `DeploymentFailed` 이벤트 payload 생성/발행 |
| Slack 승인 자동 실행 | [lambda/slack-approval-handler](lambda/slack-approval-handler), [lambda/deployment-action-executor](lambda/deployment-action-executor) | Slack 승인 버튼 수신 후 rollback/fix/change workflow 자동 dispatch |
| Rollback 요청 workflow | [.github/workflows/rollback.yml](.github/workflows/rollback.yml) | 승인 후 `gympt-gitops` values image tag를 직접 이전 tag로 갱신 |
| Manual fix workflow | [.github/workflows/manual-fix.yml](.github/workflows/manual-fix.yml) | 승인 후 수동 조치 이슈와 실행 기록 생성 |
| Change apply workflow | [.github/workflows/change-apply.yml](.github/workflows/change-apply.yml) | 승인 후 change 실행 기록과 이슈 생성 |
| Lambda 패키징 | [scripts/lambda/package-analysis-orchestrator.sh](scripts/lambda/package-analysis-orchestrator.sh) | Terraform apply 전 Bedrock adapter, `ai-agent` fallback, runbook, Athena query를 포함한 zip 생성 |
| Runbook | [scripts/runbooks](scripts/runbooks) | alert별 운영 확인 스크립트 |
| Lambda Orchestrator | [lambda/analysis-orchestrator](lambda/analysis-orchestrator) | EventBridge 이후 Athena/AI/Slack 분석 오케스트레이션 |
| Bedrock AI 분석 | [lambda/analysis-orchestrator/bedrock_agent.py](lambda/analysis-orchestrator/bedrock_agent.py) | Athena summary와 alert를 Bedrock 모델에 전달해 원인 후보와 조치 추천 생성 |
| Local AI fallback | [ai-agent](ai-agent) | Bedrock 비활성/실패 시 rule 기반 원인 후보와 조치 추천 생성 |
| Athena | [athena](athena) | query, query template, external table schema |
| Infra | [infra](infra) | Terraform 기준 AWS 리소스 scaffold |
| Schema | [schemas](schemas) | EventBridge, AI, Slack, rollback JSON schema |
| Dashboard | [dashboard](dashboard) | CD Quality Gate 운영 콘솔, local backend API, demo/live adapter, dashboard data contract |
| AWS 비용 절감 | [scripts/aws/destroy-terraform-stack.sh](scripts/aws/destroy-terraform-stack.sh) | 퇴근 전 Terraform stack destroy |
| Dashboard AWS 삭제 | [scripts/aws/destroy-dashboard-stack.sh](scripts/aws/destroy-dashboard-stack.sh) | dashboard S3/CloudFront/API Gateway/Lambda/DynamoDB만 Terraform target destroy |
| 로컬 통합 테스트 | [scripts/test-local.sh](scripts/test-local.sh) | fixture 기반 전체 흐름 검증 |

파일별 역할과 실제 실행 흐름은 [Runtime File Role and Architecture Flow](docs/20-implementation/26-runtime-file-role-and-architecture-flow.md)를 기준으로 본다. 이 문서는 `cd-quality-gate-ai-incident-analysis.drawio`의 각 박스가 어떤 `yml`, `sh`, `py`, Terraform 파일로 실행되는지 연결한다.

## 현재 결정 사항

| 항목 | 결정 |
| --- | --- |
| 1차 적용 대상 | `backend-api-prod` |
| Namespace | `gympt-prod` |
| Argo CD App | `backend-api-prod` |
| Deployment | `backend-api-prod` |
| EventBridge | 개인 파트 전용 bus 사용: `cd-quality-gate-prod-bus` |
| Slack Channel | 신규 채널 사용: `#cd-deploy-alarm` |
| Infra 관리 | Terraform 기준 |
| 비용 태그 | `Project=cd-quality-gate`, `Environment=dev/prod`, `CostControl=auto-stop` |
| 알림 종류 | 배포 완료, CD 실패 1차 알림, AI 분석/rollback/fix/change 승인 알림 |
| AI 분석 엔진 | 운영 기본값은 Amazon Bedrock, local fallback은 `ai-agent` rule analyzer |

Quality Gate는 backend-api alert만 보지 않는다. `gympt-ops/gympt-gitops/platform/monitoring`의 PrometheusRule과 dashboard를 기준으로 backend, Kubernetes, SQS, GPU, Redis, Bedrock 관련 alert를 5분 window에서 함께 평가한다.

평가 dashboard:

```text
api-latency
eks-overview
jvm-metrics
gpu-metrics
redis-metrics
sqs-metrics
```

Slack 2차 알림의 승인 버튼을 누르면 API Gateway가 `slack-approval-handler`를 호출하고, `DeploymentActionApproved` 이벤트를 거쳐 `deployment-action-executor`가 action type별 GitHub workflow를 자동 실행한다. 실제 rollback은 `cd-quality-gate` workflow가 GitOps image tag를 직접 되돌리고, change runbook은 GitOps values를 자동 patch한다.

자동 rollback은 `cd-quality-gate`의 `rollback.yml`이 `hj-3/gympt-gitops`의 `charts/backend-api/values-prod.yaml` image tag를 직접 이전 tag로 갱신하는 방식으로 맞춘다. 이 방식은 사용자가 `gympt-gitops` collaborator 권한을 갖고, `cd-quality-gate`에 저장한 PAT가 `gympt-gitops` contents write 권한을 갖는다는 전제다. `restart_deployment`, `scale_replicas`, `increase_memory`, `increase_hpa`는 `change-apply.yml`이 GitOps values를 수정한다. DR은 현재 gympt-ops에 실제 전환 switch가 없으므로 운영 action에서 제외한다.

rollback 이후에는 Argo CD가 GitOps tag 변경을 감지해 EKS를 되돌리고, 기존 app 배포 workflow는 배포 완료 후 `cd-quality-gate-architecture`의 `quality-gate.yml`을 호출해야 한다. Quality Gate가 통과하면 Slack `#cd-deploy-alarm`으로 배포 완료 알림을 보낸다.

ServiceMonitor 정합성 확인 결과, 기존 `platform/monitoring/servicemonitor-backend-api.yaml`는 dev namespace인 `backend-api` 기준이지만, Helm chart 내부 ServiceMonitor template은 `.Release.Namespace`를 사용한다. `backend-api-prod` Application의 destination namespace는 `gympt-prod`이므로 Quality Gate는 `gympt-prod` 기준으로 평가한다.

## 로컬에서 빠르게 확인

한 번에 전체 로컬 검증:

```bash
scripts/test-local.sh
```

이 테스트는 backend alert뿐 아니라 SQS, Redis, GPU fixture alert도 Quality Gate에서 잡히는지 확인한다.

대시보드 backend 포함 실행:

```bash
node dashboard/server.mjs
```

브라우저:

```text
http://localhost:5173
```

## 퇴근 전 AWS 비용 절감

이 프로젝트의 AWS 리소스는 Lambda, EventBridge, API Gateway, Athena, S3처럼 serverless 관리 리소스가 중심이다. 그래서 퇴근 전 비용 정리는 stop/scale down이 아니라 Terraform stack destroy를 기준으로 한다. 기본 실행은 dry-run이며 destroy plan만 확인한다.

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

이 스크립트는 Terraform state에 있는 `cd-quality-gate-architecture` stack만 삭제한다. 기존에 수동으로 만든 Slack/GitHub Secrets Manager secret은 state에서 제거해 destroy 대상에서 제외한다.

## 문서 읽는 순서

처음 보는 사람은 아래 순서로 읽으면 된다.

1. [DOC-00 Overview](docs/00-overview/00-overview.md)
2. [DOC-01 Old vs New](docs/00-overview/01-old-vs-new.md)
3. [DOC-04 Architecture](docs/10-architecture/04-architecture.md)
4. [DOC-05 Detailed Flows](docs/10-architecture/05-detailed-flows.md)
5. [DOC-07 Quality Gate Rules](docs/10-architecture/07-quality-gate-rules.md)
6. [DOC-09 Implementation Plan](docs/20-implementation/09-implementation-plan.md)
7. [DOC-14 Implementation File Architecture](docs/20-implementation/14-implementation-file-architecture.md)
8. [DOC-15 GitHub Actions Workflow Design](docs/20-implementation/15-github-actions-workflow-design.md)
9. [DOC-22 Test and Validation Plan](docs/20-implementation/22-test-and-validation-plan.md)
10. [DOC-24 Demo Scenario](docs/30-presentation/12-demo-scenario.md)

전체 문서는 [docs/README.md](docs/README.md)에서 확인한다.

작업 이력과 변경 이유는 [work-log.md](work-log.md)에 기록한다.

## 문서 목차

### 00. Overview

| ID | 문서 | 목적 |
| --- | --- | --- |
| DOC-00 | [Overview](docs/00-overview/00-overview.md) | 주제, 핵심 요약, 전체 문서 지도 |
| DOC-01 | [Old vs New](docs/00-overview/01-old-vs-new.md) | 기존 배포 구조와 개선 구조 비교 |
| DOC-02 | [Background and Problems](docs/00-overview/02-background-and-problems.md) | 배경, 문제 정의, 왜 필요한지 |
| DOC-03 | [Goals and Scope](docs/00-overview/03-goals-and-scope.md) | 목표, MVP 범위, 비범위 |

### 10. Architecture

| ID | 문서 | 목적 |
| --- | --- | --- |
| DOC-04 | [Architecture](docs/10-architecture/04-architecture.md) | 전체 아키텍처와 단계별 구조 |
| DOC-05 | [Detailed Flows](docs/10-architecture/05-detailed-flows.md) | 정상/실패/AI 분석 상세 흐름 |
| DOC-06 | [Components](docs/10-architecture/06-components.md) | GitHub Actions, Argo CD, Prometheus 등 컴포넌트 |
| DOC-07 | [Quality Gate Rules](docs/10-architecture/07-quality-gate-rules.md) | 배포 검증 기준과 서비스별 지표 |

### 20. Implementation

| ID | 문서 | 목적 |
| --- | --- | --- |
| DOC-08 | [Events and Slack Messages](docs/20-implementation/08-events-and-slack-messages.md) | EventBridge payload와 Slack 메시지 설계 |
| DOC-09 | [Implementation Plan](docs/20-implementation/09-implementation-plan.md) | Phase별 구현 계획과 완료 기준 |
| DOC-14 | [Implementation File Architecture](docs/20-implementation/14-implementation-file-architecture.md) | 실제 구현 시 사용할 폴더와 파일 구조 |
| DOC-15 | [GitHub Actions Workflow Design](docs/20-implementation/15-github-actions-workflow-design.md) | CD/Quality Gate workflow 설계 |
| DOC-16 | [Prometheus Rule and Query Examples](docs/20-implementation/16-prometheus-rule-and-query-examples.md) | PrometheusRule과 PromQL 예시 |
| DOC-17 | [Runbook Script Design](docs/20-implementation/17-runbook-script-design.md) | alert-specific shell script 설계 |
| DOC-18 | [Lambda Analysis Orchestrator Design](docs/20-implementation/18-lambda-analysis-orchestrator-design.md) | EventBridge 이후 분석 Lambda 설계 |
| DOC-19 | [Athena Log Analysis Design](docs/20-implementation/19-athena-log-analysis-design.md) | Athena 로그 분석 query와 summary 설계 |
| DOC-20 | [AI Agent Prompt and Output Design](docs/20-implementation/20-ai-agent-prompt-and-output-design.md) | AI Agent 입력, prompt, 출력 schema 설계 |
| DOC-21 | [Terraform Infra Design](docs/20-implementation/21-terraform-infra-design.md) | AWS 리소스 Terraform 설계 |
| DOC-22 | [Test and Validation Plan](docs/20-implementation/22-test-and-validation-plan.md) | 테스트 fixture와 검증 시나리오 |
| DOC-23 | [Security and IAM Policy](docs/20-implementation/23-security-and-iam-policy.md) | 권한, secret, 보안 기준 |
| DOC-26 | [Operations Runbook](docs/20-implementation/24-operations-runbook.md) | 운영자 장애 대응 절차 |
| DOC-27 | [Rollback Workflow Design](docs/20-implementation/25-rollback-workflow-design.md) | 승인 기반 rollback workflow 설계 |
| DOC-31 | [Runtime File Role and Architecture Flow](docs/20-implementation/26-runtime-file-role-and-architecture-flow.md) | yml/sh/py 파일별 역할과 실제 아키텍처 실행 흐름 |
| DOC-32 | [GitHub Secrets and Runtime Values](docs/20-implementation/27-github-secrets-and-runtime-values.md) | 실제 연결 전 GitHub Secrets, AWS Secrets Manager, runtime 값 정리 |
| DOC-33 | [Pre-Apply Verification Checklist](docs/20-implementation/28-pre-apply-verification-checklist.md) | apply 전 Terraform, dispatch workflow, Slack signing secret 점검 |
| DOC-34 | [Dashboard Control Center Checklist](docs/20-implementation/29-dashboard-control-center-checklist.md) | dashboard local backend, 버튼, live 연결 체크리스트 |
| DOC-35 | [Final Status and User Checklist](docs/20-implementation/30-final-status-and-user-checklist.md) | 지금까지 완료된 것, 남은 것, 사용자가 해야 할 일 |
| DOC-36 | [GymPT App to GitOps to Quality Gate Flow](docs/20-implementation/31-gympt-app-to-gitops-to-quality-gate-flow.md) | gympt-apps에서 gympt-gitops, cd-quality-gate까지 전체 세부 흐름 |

### 30. Presentation

| ID | 문서 | 목적 |
| --- | --- | --- |
| DOC-10 | [Expected Effects](docs/30-presentation/10-expected-effects.md) | 기대 효과와 팀원 파트 연결 |
| DOC-11 | [Presentation Notes](docs/30-presentation/11-presentation-notes.md) | 발표용 핵심 문장과 설명 스크립트 |
| DOC-24 | [Demo Scenario](docs/30-presentation/12-demo-scenario.md) | 발표/시연 시나리오 |
| DOC-29 | [Limitations and Future Work](docs/30-presentation/13-limitations-and-future-work.md) | 한계와 향후 확장 방향 |

### 90. Reference

| ID | 문서 | 목적 |
| --- | --- | --- |
| DOC-12 | [IDs and Terms](docs/90-reference/12-ids-and-terms.md) | 컴포넌트, 흐름, 이벤트 식별자 정리 |
| DOC-13 | [Repository Architecture](docs/90-reference/13-repository-architecture.md) | 문서 저장소 폴더 구조와 파일별 역할 |
| DOC-25 | [Configuration Reference](docs/90-reference/14-configuration-reference.md) | 설정 파일과 필드 기준 |
| DOC-28 | [Data Schema Reference](docs/90-reference/15-data-schema-reference.md) | 이벤트와 분석 payload schema |
| DOC-30 | [GymPT Ops Connection Map](docs/90-reference/16-gympt-ops-connection-map.md) | gympt-ops 연결값 조사 결과 |

## 아키텍처 다이어그램

- [cd-quality-gate-ai-incident-analysis.drawio](cd-quality-gate-ai-incident-analysis.drawio)

## 작업 원칙

```text
gympt-ops는 참고만 한다.
실제 수정은 이 저장소에서 먼저 한다.
나중에 gympt-ops에 붙일 때는 최소 변경으로 적용한다.
AWS 리소스는 Terraform으로 만들고, 퇴근 전 cd-quality-gate stack만 destroy한다.
rollback 같은 위험한 조치는 운영자 승인 이후에만 실행한다.
```

