# 20. Implementation

| ID | 문서 | 목적 |
| --- | --- | --- |
| DOC-08 | [Events and Slack Messages](08-events-and-slack-messages.md) | 이벤트와 Slack 메시지 |
| DOC-09 | [Implementation Plan](09-implementation-plan.md) | Phase별 구현 계획 |
| DOC-14 | [Implementation File Architecture](14-implementation-file-architecture.md) | 실제 구현용 폴더와 파일 구조 |
| DOC-15 | [GitHub Actions Workflow Design](15-github-actions-workflow-design.md) | CD/Quality Gate workflow 설계 |
| DOC-16 | [Prometheus Rule and Query Examples](16-prometheus-rule-and-query-examples.md) | PrometheusRule과 PromQL 예시 |
| DOC-17 | [Runbook Script Design](17-runbook-script-design.md) | alert-specific shell script 설계 |
| DOC-18 | [Lambda Analysis Orchestrator Design](18-lambda-analysis-orchestrator-design.md) | EventBridge 이후 분석 Lambda 설계 |
| DOC-19 | [Athena Log Analysis Design](19-athena-log-analysis-design.md) | Athena 로그 분석 query와 summary 설계 |
| DOC-20 | [AI Agent Prompt and Output Design](20-ai-agent-prompt-and-output-design.md) | AI Agent 입력, prompt, 출력 schema 설계 |
| DOC-21 | [Terraform Infra Design](21-terraform-infra-design.md) | AWS 리소스 Terraform 설계 |
| DOC-22 | [Test and Validation Plan](22-test-and-validation-plan.md) | 테스트 fixture와 검증 시나리오 |
| DOC-23 | [Security and IAM Policy](23-security-and-iam-policy.md) | 권한, secret, 보안 기준 |
| DOC-26 | [Operations Runbook](24-operations-runbook.md) | 운영자 장애 대응 절차 |
| DOC-27 | [Rollback Workflow Design](25-rollback-workflow-design.md) | 승인 기반 rollback workflow 설계 |
| DOC-31 | [Runtime File Role and Architecture Flow](26-runtime-file-role-and-architecture-flow.md) | yml/sh/py 파일별 역할과 실제 아키텍처 실행 흐름 |
| DOC-32 | [GitHub Secrets and Runtime Values](27-github-secrets-and-runtime-values.md) | 실제 연결 전 GitHub Secrets, AWS Secrets Manager, runtime 값 정리 |
| DOC-33 | [Pre-Apply Verification Checklist](28-pre-apply-verification-checklist.md) | apply 전 Terraform, dispatch workflow, Slack signing secret 점검 |
| DOC-34 | [Dashboard Control Center Checklist](29-dashboard-control-center-checklist.md) | dashboard local backend, 버튼, live 연결 체크리스트 |
