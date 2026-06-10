# DOC-12. IDs and Terms

## 1. 문서 식별자

| ID | 이름 | 설명 |
| --- | --- | --- |
| DOC-00 | Overview | 전체 요약 |
| DOC-01 | Old vs New | 기존 구조와 개선 구조 비교 |
| DOC-02 | Background and Problems | 배경과 문제 정의 |
| DOC-03 | Goals and Scope | 목표와 범위 |
| DOC-04 | Architecture | 전체 아키텍처 |
| DOC-05 | Detailed Flows | 상세 동작 흐름 |
| DOC-06 | Components | 주요 컴포넌트 |
| DOC-07 | Quality Gate Rules | 배포 검증 기준 |
| DOC-08 | Events and Slack Messages | 이벤트와 Slack 메시지 |
| DOC-09 | Implementation Plan | 구현 계획 |
| DOC-10 | Expected Effects | 기대 효과 |
| DOC-11 | Presentation Notes | 발표 노트 |
| DOC-12 | IDs and Terms | 식별자와 용어 |
| DOC-13 | Repository Architecture | 문서 저장소 구조 |
| DOC-14 | Implementation File Architecture | 실제 구현용 폴더와 파일 구조 |
| DOC-15 | GitHub Actions Workflow Design | CD/Quality Gate workflow 설계 |
| DOC-16 | Prometheus Rule and Query Examples | PrometheusRule과 PromQL 예시 |
| DOC-17 | Runbook Script Design | alert-specific shell script 설계 |
| DOC-18 | Lambda Analysis Orchestrator Design | EventBridge 이후 분석 Lambda 설계 |
| DOC-19 | Athena Log Analysis Design | Athena 로그 분석 query와 summary 설계 |
| DOC-20 | AI Agent Prompt and Output Design | AI Agent 입력, prompt, 출력 schema 설계 |
| DOC-21 | Terraform Infra Design | AWS 리소스 Terraform 설계 |
| DOC-22 | Test and Validation Plan | 테스트 fixture와 검증 시나리오 |
| DOC-23 | Security and IAM Policy | 권한, secret, 보안 기준 |
| DOC-24 | Demo Scenario | 발표/시연 시나리오 |
| DOC-25 | Configuration Reference | 설정 파일과 필드 기준 |
| DOC-26 | Operations Runbook | 운영자 장애 대응 절차 |
| DOC-27 | Rollback Workflow Design | 승인 기반 rollback workflow 설계 |
| DOC-28 | Data Schema Reference | 이벤트와 분석 payload schema |
| DOC-29 | Limitations and Future Work | 한계와 향후 확장 방향 |

## 2. 컴포넌트 식별자

| ID | Component | 역할 |
| --- | --- | --- |
| CMP-GHA | GitHub Actions CD | CD 실행, health check, EventBridge 이벤트 발행 |
| CMP-GITOPS | GitOps Repository | image tag 변경 저장소 |
| CMP-ARGO | Argo CD | GitOps 기반 Kubernetes 배포 및 rollback |
| CMP-EKS | Amazon EKS | 서비스 실행 환경 |
| CMP-PROM | Prometheus | alert와 metric 기반 품질 게이트 |
| CMP-GRAF | Grafana | dashboard와 운영 확인 링크 제공 |
| CMP-SLACK1 | Slack 1st Alert | 배포 실패 1차 알림 |
| CMP-EVB | EventBridge | DeploymentFailed 이벤트 라우팅 |
| CMP-LAMBDA | Lambda Orchestrator | Athena/AI 분석 오케스트레이션 |
| CMP-ATHENA | Athena | S3 로그 SQL 분석 |
| CMP-S3LOG | S3 Central Logs | 원본 로그 저장소 |
| CMP-S3RESULT | S3 Analysis Result | 분석 결과 JSON 저장소 |
| CMP-AI | AI Agent | 원인 분석과 조치 추천 |
| CMP-RUNBOOK | Runbook Scripts | alert-specific shell scripts |
| CMP-SLACK2 | Slack 2nd Alert | AI 분석 결과 알림 |
| CMP-OPERATOR | Operator | 조치 승인 및 실행 주체 |

## 3. 흐름 식별자

| ID | Flow | 설명 |
| --- | --- | --- |
| FLW-NORMAL | Normal Deployment | 정상 배포 성공 흐름 |
| FLW-GATE-FAIL | Quality Gate Fail | Prometheus alert 기반 배포 실패 흐름 |
| FLW-EVENT | Event Trigger | EventBridge DeploymentFailed 이벤트 발행 |
| FLW-LOG | Log Analysis | Lambda와 Athena 기반 S3 로그 분석 |
| FLW-AI | AI Analysis | AI Agent 원인 분석과 추천 생성 |
| FLW-APPROVAL | Approval | 운영자 승인 기반 rollback/manual fix/DR |

## 4. 이벤트 식별자

| ID | Event | 설명 |
| --- | --- | --- |
| EVT-DEPLOYMENT-FAILED | DeploymentFailed | CD Quality Gate 실패 이벤트 |
| EVT-ROLLBACK-APPROVED | RollbackApproved | Slack 또는 운영자 승인으로 rollback 실행 |
| EVT-DR-APPROVED | DRApproved | DR Runbook 실행 승인 |

## 5. 알림 식별자

| ID | Notification | 설명 |
| --- | --- | --- |
| NTF-SLACK-DEPLOY-FAILED | Slack 1st Alert | 배포 실패 감지 즉시 발송 |
| NTF-SLACK-AI-RESULT | Slack 2nd Alert | AI 분석 결과와 추천 조치 발송 |
| NTF-SLACK-APPROVAL | Slack Approval | rollback/manual fix/DR 승인 요청 |

## 6. 산출물 식별자

| ID | Artifact | 설명 |
| --- | --- | --- |
| ART-PROM-ALERTS | prometheus-alerts.json | Prometheus firing alert 스냅샷 |
| ART-ATHENA-SUMMARY | athena-summary.json | Athena 로그 분석 요약 |
| ART-AI-RECOMMENDATION | ai-recommendation.json | AI Agent 추천 결과 |
| ART-RUNBOOK-SCRIPT | alert-specific shell script | alert별 대응 shell script |
| ART-DIAGRAM | draw.io diagram | 전체 아키텍처 다이어그램 |

## 7. 주요 용어

| Term | 의미 |
| --- | --- |
| CD Quality Gate | 배포 직후 서비스 상태를 검증해 CD 성공/실패를 결정하는 품질 게이트 |
| Health Check Window | 배포 직후 Prometheus metric과 alert를 확인하는 시간 구간 |
| DeploymentFailed | Quality Gate 실패 시 발행되는 EventBridge 이벤트 |
| AI Incident Analysis | Athena 로그 결과와 Runbook을 기반으로 원인과 대응을 분석하는 단계 |
| Runbook Alert-specific Shell Scripts | alert 유형별로 실행하거나 참고할 수 있는 대응 shell script |
| Rollback | 이전 image tag 또는 Argo CD revision으로 되돌리는 대응 |
| Manual Fix | 코드, 설정, secret, migration 등을 사람이 수정하는 대응 |
| DR | 장애 범위가 인프라/리전/핵심 데이터 계층으로 확대될 때 승인 기반으로 실행하는 복구 대응 |
