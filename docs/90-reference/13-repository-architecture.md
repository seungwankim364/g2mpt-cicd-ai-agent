# DOC-13. Repository Architecture

## 1. 목적

이 문서는 현재 문서 저장소의 폴더 구조와 파일 역할을 정리한다.

시스템 구현 시 사용할 실제 코드 폴더 구조는 `DOC-14. Implementation File Architecture`에서 설명한다.  
이 문서는 현재 설계 문서들을 어떻게 분류하고 찾아야 하는지 설명하는 **문서 저장소 구조 문서**다.

## 2. 전체 폴더 구조

```text
cd-quality-gate-architecture/
  README.md
  cd-quality-gate-ai-incident-analysis.drawio
  docs/
    README.md
    00-overview/
      README.md
      00-overview.md
      01-old-vs-new.md
      02-background-and-problems.md
      03-goals-and-scope.md
    10-architecture/
      README.md
      04-architecture.md
      05-detailed-flows.md
      06-components.md
      07-quality-gate-rules.md
    20-implementation/
      README.md
      08-events-and-slack-messages.md
      09-implementation-plan.md
      14-implementation-file-architecture.md
      15-github-actions-workflow-design.md
      16-prometheus-rule-and-query-examples.md
      17-runbook-script-design.md
      18-lambda-analysis-orchestrator-design.md
      19-athena-log-analysis-design.md
      20-ai-agent-prompt-and-output-design.md
      21-terraform-infra-design.md
      22-test-and-validation-plan.md
      23-security-and-iam-policy.md
      24-operations-runbook.md
      25-rollback-workflow-design.md
    30-presentation/
      README.md
      10-expected-effects.md
      11-presentation-notes.md
      12-demo-scenario.md
      13-limitations-and-future-work.md
    90-reference/
      README.md
      12-ids-and-terms.md
      13-repository-architecture.md
      14-configuration-reference.md
      15-data-schema-reference.md
      16-gympt-ops-connection-map.md
```

## 3. 디렉터리 역할

| Path | ID | 역할 |
| --- | --- | --- |
| `README.md` | ROOT-README | 전체 문서의 진입점 |
| `cd-quality-gate-ai-incident-analysis.drawio` | ART-DIAGRAM | 전체 아키텍처 다이어그램 |
| `docs/README.md` | DOCS-INDEX | 문서 디렉터리 인덱스 |
| `docs/00-overview/` | DIR-OVERVIEW | 주제, 배경, 목표, Old vs New |
| `docs/10-architecture/` | DIR-ARCH | 시스템 아키텍처, 흐름, 컴포넌트, 품질 게이트 |
| `docs/20-implementation/` | DIR-IMPL | 이벤트, Slack 메시지, 구현 계획, 실제 파일 구조 |
| `docs/30-presentation/` | DIR-PRESENT | 발표용 효과, 발표 스크립트 |
| `docs/90-reference/` | DIR-REF | 식별자, 용어, 문서 저장소 구조 |

## 4. 문서 파일 역할

| Path | ID | 설명 |
| --- | --- | --- |
| `docs/00-overview/00-overview.md` | DOC-00 | 주제명, 한 줄 요약, 전체 구조, 최종 목표 |
| `docs/00-overview/01-old-vs-new.md` | DOC-01 | 기존 CD 구조와 개선된 Quality Gate 구조 비교 |
| `docs/00-overview/02-background-and-problems.md` | DOC-02 | 배경, 문제 정의, 해결 방향 |
| `docs/00-overview/03-goals-and-scope.md` | DOC-03 | 목표, MVP 범위, 비범위, 성공 기준 |
| `docs/10-architecture/04-architecture.md` | DOC-04 | CD Quality Gate와 AI Incident Analysis 전체 아키텍처 |
| `docs/10-architecture/05-detailed-flows.md` | DOC-05 | 정상 배포, 실패 배포, AI 분석, 승인 흐름 |
| `docs/10-architecture/06-components.md` | DOC-06 | GitHub Actions, Argo CD, Prometheus 등 컴포넌트별 역할 |
| `docs/10-architecture/07-quality-gate-rules.md` | DOC-07 | 배포 검증 지표와 rollback/manual fix/DR 판단 기준 |
| `docs/20-implementation/08-events-and-slack-messages.md` | DOC-08 | EventBridge 이벤트, Slack 1차/2차 알림, Athena query 예시 |
| `docs/20-implementation/09-implementation-plan.md` | DOC-09 | Phase 1~5 구현 계획과 완료 기준 |
| `docs/20-implementation/14-implementation-file-architecture.md` | DOC-14 | 실제 구현 시 사용할 코드/인프라/스크립트 폴더 구조 |
| `docs/20-implementation/15-github-actions-workflow-design.md` | DOC-15 | CD/Quality Gate workflow 설계 |
| `docs/20-implementation/16-prometheus-rule-and-query-examples.md` | DOC-16 | PrometheusRule과 PromQL 예시 |
| `docs/20-implementation/17-runbook-script-design.md` | DOC-17 | alert-specific shell script 설계 |
| `docs/20-implementation/18-lambda-analysis-orchestrator-design.md` | DOC-18 | EventBridge 이후 분석 Lambda 설계 |
| `docs/20-implementation/19-athena-log-analysis-design.md` | DOC-19 | Athena 로그 분석 query와 summary 설계 |
| `docs/20-implementation/20-ai-agent-prompt-and-output-design.md` | DOC-20 | AI Agent 입력, prompt, 출력 schema 설계 |
| `docs/20-implementation/21-terraform-infra-design.md` | DOC-21 | AWS 리소스 Terraform 설계 |
| `docs/20-implementation/22-test-and-validation-plan.md` | DOC-22 | 테스트 fixture와 검증 시나리오 |
| `docs/20-implementation/23-security-and-iam-policy.md` | DOC-23 | 권한, secret, 보안 기준 |
| `docs/20-implementation/24-operations-runbook.md` | DOC-26 | 운영자 장애 대응 절차 |
| `docs/20-implementation/25-rollback-workflow-design.md` | DOC-27 | 승인 기반 rollback workflow 설계 |
| `docs/30-presentation/10-expected-effects.md` | DOC-10 | 기대 효과와 팀원 파트 연결 |
| `docs/30-presentation/11-presentation-notes.md` | DOC-11 | 발표 스크립트와 설명 포인트 |
| `docs/30-presentation/12-demo-scenario.md` | DOC-24 | 발표/시연 시나리오 |
| `docs/30-presentation/13-limitations-and-future-work.md` | DOC-29 | 한계와 향후 확장 방향 |
| `docs/90-reference/12-ids-and-terms.md` | DOC-12 | 컴포넌트, 흐름, 이벤트, 산출물 식별자 |
| `docs/90-reference/13-repository-architecture.md` | DOC-13 | 문서 저장소 폴더 구조와 파일별 책임 |
| `docs/90-reference/14-configuration-reference.md` | DOC-25 | 설정 파일과 필드 기준 |
| `docs/90-reference/15-data-schema-reference.md` | DOC-28 | 이벤트와 분석 payload schema |
| `docs/90-reference/16-gympt-ops-connection-map.md` | DOC-30 | gympt-ops 연결값 조사 결과 |

## 5. 문서 간 관계

```text
README.md
  -> docs/README.md
  -> docs/00-overview/
  -> docs/10-architecture/
  -> docs/20-implementation/
  -> docs/30-presentation/
  -> docs/90-reference/
```

상세 설계 흐름은 다음 순서로 읽으면 된다.

```text
DOC-00 Overview
  -> DOC-01 Old vs New
  -> DOC-02 Background and Problems
  -> DOC-03 Goals and Scope
  -> DOC-04 Architecture
  -> DOC-05 Detailed Flows
  -> DOC-06 Components
  -> DOC-07 Quality Gate Rules
  -> DOC-08 Events and Slack Messages
  -> DOC-09 Implementation Plan
  -> DOC-14 Implementation File Architecture
  -> DOC-15 GitHub Actions Workflow Design
  -> DOC-16 Prometheus Rule and Query Examples
  -> DOC-17 Runbook Script Design
  -> DOC-18 Lambda Analysis Orchestrator Design
  -> DOC-19 Athena Log Analysis Design
  -> DOC-20 AI Agent Prompt and Output Design
  -> DOC-21 Terraform Infra Design
  -> DOC-22 Test and Validation Plan
  -> DOC-23 Security and IAM Policy
  -> DOC-25 Configuration Reference
  -> DOC-26 Operations Runbook
  -> DOC-27 Rollback Workflow Design
  -> DOC-28 Data Schema Reference
  -> DOC-30 GymPT Ops Connection Map
```

발표 준비 흐름은 다음 순서가 적합하다.

```text
DOC-01 Old vs New
  -> DOC-04 Architecture
  -> draw.io diagram
  -> DOC-08 Events and Slack Messages
  -> DOC-10 Expected Effects
  -> DOC-11 Presentation Notes
  -> DOC-24 Demo Scenario
  -> DOC-29 Limitations and Future Work
```

식별자 확인이 필요하면 다음 문서를 참조한다.

```text
DOC-12 IDs and Terms
```

## 6. 산출물 관점 아키텍처

```text
Architecture Diagram
  -> ART-DIAGRAM
  -> cd-quality-gate-ai-incident-analysis.drawio

Documentation Entry
  -> ROOT-README
  -> README.md

Documentation Index
  -> DOCS-INDEX
  -> docs/README.md

Concept Documents
  -> DOC-00 ~ DOC-03
  -> docs/00-overview/

Architecture Documents
  -> DOC-04 ~ DOC-07
  -> docs/10-architecture/

Implementation Documents
  -> DOC-08, DOC-09, DOC-14
  -> docs/20-implementation/

Presentation Support
  -> DOC-10, DOC-11
  -> docs/30-presentation/

Reference
  -> DOC-12, DOC-13
  -> docs/90-reference/
```

## 7. 추천 사용 방식

### 처음 보는 사람

```text
README.md
  -> docs/00-overview/00-overview.md
  -> docs/00-overview/01-old-vs-new.md
  -> docs/10-architecture/04-architecture.md
```

### 구현 담당자

```text
docs/10-architecture/06-components.md
  -> docs/10-architecture/07-quality-gate-rules.md
  -> docs/20-implementation/08-events-and-slack-messages.md
  -> docs/20-implementation/09-implementation-plan.md
  -> docs/20-implementation/14-implementation-file-architecture.md
```

### 발표 준비

```text
docs/00-overview/01-old-vs-new.md
  -> docs/10-architecture/04-architecture.md
  -> cd-quality-gate-ai-incident-analysis.drawio
  -> docs/30-presentation/11-presentation-notes.md
```

### 팀원 연동 설명

```text
docs/30-presentation/10-expected-effects.md
  -> docs/90-reference/12-ids-and-terms.md
```

## 8. 유지보수 규칙

새 문서를 추가할 때는 다음 규칙을 따른다.

```text
1. 문서 성격에 맞는 하위 디렉터리에 넣는다.
2. 파일명은 DOC 번호와 역할이 보이도록 작성한다.
3. README.md와 docs/README.md에 링크를 추가한다.
4. 필요하면 해당 하위 디렉터리 README.md에도 링크를 추가한다.
5. 필요하면 DOC-12 IDs and Terms에 식별자를 추가한다.
6. 시스템 아키텍처 변경은 draw.io와 DOC-04를 함께 갱신한다.
7. 실제 구현 폴더 구조 변경은 DOC-14를 함께 갱신한다.
```

예시:

```text
docs/20-implementation/15-runbook-script-design.md
docs/20-implementation/16-prometheus-rule-examples.md
docs/20-implementation/17-github-actions-workflow-example.md
```
