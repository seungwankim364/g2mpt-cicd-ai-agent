# Documentation Index

## 00. Overview

| ID | 문서 | 목적 |
| --- | --- | --- |
| DOC-00 | [Overview](00-overview/00-overview.md) | 주제, 핵심 요약, 전체 문서 지도 |
| DOC-01 | [Old vs New](00-overview/01-old-vs-new.md) | 기존 배포 구조와 개선 구조 비교 |
| DOC-02 | [Background and Problems](00-overview/02-background-and-problems.md) | 배경, 문제 정의 |
| DOC-03 | [Goals and Scope](00-overview/03-goals-and-scope.md) | 목표, MVP 범위, 성공 기준 |

## 10. Architecture

| ID | 문서 | 목적 |
| --- | --- | --- |
| DOC-04 | [Architecture](10-architecture/04-architecture.md) | 전체 시스템 아키텍처 |
| DOC-05 | [Detailed Flows](10-architecture/05-detailed-flows.md) | 정상/실패/AI 분석 상세 흐름 |
| DOC-06 | [Components](10-architecture/06-components.md) | 컴포넌트별 역할 |
| DOC-07 | [Quality Gate Rules](10-architecture/07-quality-gate-rules.md) | 배포 검증 기준 |

## 20. Implementation

| ID | 문서 | 목적 |
| --- | --- | --- |
| DOC-08 | [Events and Slack Messages](20-implementation/08-events-and-slack-messages.md) | 이벤트와 Slack 메시지 |
| DOC-09 | [Implementation Plan](20-implementation/09-implementation-plan.md) | Phase별 구현 계획 |
| DOC-14 | [Implementation File Architecture](20-implementation/14-implementation-file-architecture.md) | 실제 구현용 폴더와 파일 구조 |
| DOC-15 | [GitHub Actions Workflow Design](20-implementation/15-github-actions-workflow-design.md) | CD/Quality Gate workflow 설계 |
| DOC-16 | [Prometheus Rule and Query Examples](20-implementation/16-prometheus-rule-and-query-examples.md) | PrometheusRule과 PromQL 예시 |
| DOC-17 | [Runbook Script Design](20-implementation/17-runbook-script-design.md) | alert-specific shell script 설계 |
| DOC-18 | [Lambda Analysis Orchestrator Design](20-implementation/18-lambda-analysis-orchestrator-design.md) | EventBridge 이후 분석 Lambda 설계 |
| DOC-19 | [Athena Log Analysis Design](20-implementation/19-athena-log-analysis-design.md) | Athena 로그 분석 query와 summary 설계 |
| DOC-20 | [AI Agent Prompt and Output Design](20-implementation/20-ai-agent-prompt-and-output-design.md) | AI Agent 입력, prompt, 출력 schema 설계 |
| DOC-21 | [Terraform Infra Design](20-implementation/21-terraform-infra-design.md) | AWS 리소스 Terraform 설계 |
| DOC-22 | [Test and Validation Plan](20-implementation/22-test-and-validation-plan.md) | 테스트 fixture와 검증 시나리오 |
| DOC-23 | [Security and IAM Policy](20-implementation/23-security-and-iam-policy.md) | 권한, secret, 보안 기준 |
| DOC-26 | [Operations Runbook](20-implementation/24-operations-runbook.md) | 운영자 장애 대응 절차 |
| DOC-27 | [Rollback Workflow Design](20-implementation/25-rollback-workflow-design.md) | 승인 기반 rollback workflow 설계 |

## 30. Presentation

| ID | 문서 | 목적 |
| --- | --- | --- |
| DOC-10 | [Expected Effects](30-presentation/10-expected-effects.md) | 기대 효과 |
| DOC-11 | [Presentation Notes](30-presentation/11-presentation-notes.md) | 발표 스크립트 |
| DOC-24 | [Demo Scenario](30-presentation/12-demo-scenario.md) | 발표/시연 시나리오 |
| DOC-29 | [Limitations and Future Work](30-presentation/13-limitations-and-future-work.md) | 한계와 향후 확장 방향 |

## 90. Reference

| ID | 문서 | 목적 |
| --- | --- | --- |
| DOC-12 | [IDs and Terms](90-reference/12-ids-and-terms.md) | 식별자와 용어 |
| DOC-13 | [Repository Architecture](90-reference/13-repository-architecture.md) | 문서 저장소 구조 |
| DOC-25 | [Configuration Reference](90-reference/14-configuration-reference.md) | 설정 파일과 필드 기준 |
| DOC-28 | [Data Schema Reference](90-reference/15-data-schema-reference.md) | 이벤트와 분석 payload schema |
