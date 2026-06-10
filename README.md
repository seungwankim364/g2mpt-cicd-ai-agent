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
GitHub Actions CD
  -> Argo CD sync / rollout 확인
  -> Prometheus alert 조회
  -> Quality Gate 판단
  -> 정상: CD 성공
  -> 실패: CD 실패 + Slack 1차 알림
  -> EventBridge DeploymentFailed 이벤트
  -> Lambda Orchestrator
  -> Athena 로그 분석
  -> AI Agent 원인 분석
  -> Slack 2차 알림
  -> 운영자 승인 기반 rollback 또는 manual fix
```

## 현재 구현 상태

`docs/10-architecture`와 `docs/20-implementation/14-implementation-file-architecture.md` 기준으로 실제 구현 scaffold를 채워둔 상태다. 외부 AWS, Slack, Prometheus는 실제 값을 넣기 전에도 fixture와 dry-run으로 흐름을 확인할 수 있다.

| 구분 | 위치 | 설명 |
| --- | --- | --- |
| CD workflow | [.github/workflows/cd.yml](.github/workflows/cd.yml) | GitOps update, Argo CD wait, rollout 확인 후 Quality Gate 호출 |
| Quality Gate workflow | [.github/workflows/quality-gate.yml](.github/workflows/quality-gate.yml) | Prometheus 조회, Gate 판단, Slack/EventBridge 연동 |
| 샘플 workflow | [.github/workflows/cd-quality-gate-sample.yml](.github/workflows/cd-quality-gate-sample.yml) | fixture 기반 Quality Gate 실행 예시 |
| CD 스크립트 | [scripts/cd](scripts/cd) | GitOps image tag 수정, Argo CD 대기, rollout 확인 |
| 서비스 설정 | [config/services/backend-api.yaml](config/services/backend-api.yaml) | backend-api 기준 서비스 설정 |
| Quality Gate 설정 | [config/quality-gate](config/quality-gate) | threshold, alert mapping, Grafana dashboard 설정 |
| Prometheus 조회 | [scripts/quality-gate/query-prometheus-alerts.sh](scripts/quality-gate/query-prometheus-alerts.sh) | Prometheus alert 조회 또는 fixture 사용 |
| Gate 판단 | [scripts/quality-gate/evaluate-quality-gate.py](scripts/quality-gate/evaluate-quality-gate.py) | firing alert 기반 pass/fail 판단 |
| Grafana 링크 | [scripts/quality-gate/build-grafana-links.py](scripts/quality-gate/build-grafana-links.py) | Slack에 넣을 dashboard 링크 생성 |
| Slack 1차 알림 | [scripts/quality-gate/send-slack-first-alert.py](scripts/quality-gate/send-slack-first-alert.py) | 실패 알림 payload 생성 또는 전송 |
| EventBridge 발행 | [scripts/quality-gate/publish-eventbridge-event.sh](scripts/quality-gate/publish-eventbridge-event.sh) | `DeploymentFailed` 이벤트 payload 생성/발행 |
| Runbook | [scripts/runbooks](scripts/runbooks) | alert별 운영 확인 스크립트 |
| Lambda Orchestrator | [lambda/analysis-orchestrator](lambda/analysis-orchestrator) | EventBridge 이후 Athena/AI/Slack 분석 오케스트레이션 |
| AI Agent | [ai-agent](ai-agent) | Athena summary와 alert를 바탕으로 원인 후보와 조치 추천 생성 |
| Athena | [athena](athena) | query, query template, external table schema |
| Infra | [infra](infra) | Terraform/SAM 기반 AWS 리소스 scaffold |
| Schema | [schemas](schemas) | EventBridge, AI, Slack, rollback JSON schema |
| AWS 비용 절감 | [scripts/aws/stop-after-work.sh](scripts/aws/stop-after-work.sh) | 퇴근 전 dev 리소스 stop/scale down |

## 로컬에서 빠르게 확인

정상 fixture로 Quality Gate pass 확인:

```bash
FIXTURE_FILE=tests/fixtures/prometheus-alerts.normal.json \
OUTPUT_FILE=/tmp/quality-gate-alerts-normal.json \
scripts/quality-gate/query-prometheus-alerts.sh

scripts/quality-gate/evaluate-quality-gate.py \
  --alerts-file /tmp/quality-gate-alerts-normal.json \
  --service backend-api \
  --namespace prod \
  --alert-names BackendHighErrorRate,BackendHighLatency,BackendPodRestarting \
  --output-file /tmp/quality-gate-result-normal.json
```

실패 fixture로 Quality Gate fail 확인:

```bash
FIXTURE_FILE=tests/fixtures/prometheus-alerts.firing.json \
OUTPUT_FILE=/tmp/quality-gate-alerts-firing.json \
scripts/quality-gate/query-prometheus-alerts.sh

scripts/quality-gate/evaluate-quality-gate.py \
  --alerts-file /tmp/quality-gate-alerts-firing.json \
  --service backend-api \
  --namespace prod \
  --alert-names BackendHighErrorRate,BackendHighLatency,BackendPodRestarting \
  --output-file /tmp/quality-gate-result-firing.json
```

실패 시 exit code는 `1`이다. GitHub Actions에서는 이 값을 이용해 CD job을 실패 처리한다.

## 퇴근 전 AWS 비용 절감

개인 실습용 AWS 리소스는 tag 기준으로만 중지하거나 scale down한다. 기본 실행은 dry-run이다.

```bash
AWS_REGION=ap-northeast-2 \
TAG_KEY=Project \
TAG_VALUE=cd-quality-gate \
ENVIRONMENT=dev \
scripts/aws/stop-after-work.sh
```

실제로 실행하려면 `--execute`를 붙인다.

```bash
AWS_REGION=ap-northeast-2 \
TAG_KEY=Project \
TAG_VALUE=cd-quality-gate \
ENVIRONMENT=dev \
scripts/aws/stop-after-work.sh --execute
```

대상은 `Project=cd-quality-gate`, `Environment=dev` tag가 붙은 리소스다. `prod` 환경은 기본적으로 차단한다.

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

## 아키텍처 다이어그램

- [cd-quality-gate-ai-incident-analysis.drawio](cd-quality-gate-ai-incident-analysis.drawio)

## 작업 원칙

```text
gympt-ops는 참고만 한다.
실제 수정은 이 저장소에서 먼저 한다.
나중에 gympt-ops에 붙일 때는 최소 변경으로 적용한다.
AWS 리소스는 dev tag를 붙이고, 퇴근 전 stop/scale down한다.
rollback 같은 위험한 조치는 운영자 승인 이후에만 실행한다.
```

