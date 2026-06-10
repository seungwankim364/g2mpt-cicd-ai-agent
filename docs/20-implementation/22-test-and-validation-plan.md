# DOC-22. Test and Validation Plan

## 1. 목적

CD Quality Gate와 AI Incident Analysis Pipeline이 의도한 조건에서 성공/실패를 정확히 판단하는지 검증하기 위한 테스트 계획을 정의한다.

## 2. 테스트 범위

```text
GitHub Actions workflow
Prometheus alert query
Quality Gate decision
EventBridge payload
Lambda Orchestrator
Athena summary generation
AI Agent output
Slack message rendering
Runbook mapping
```

## 3. 테스트 Fixture

권장 fixture:

```text
tests/fixtures/prometheus-alerts.normal.json
tests/fixtures/prometheus-alerts.firing.json
tests/fixtures/deployment-failed.sample.json
tests/fixtures/athena-summary.sample.json
tests/fixtures/ai-recommendation.sample.json
tests/fixtures/slack-message.sample.json
```

## 4. Quality Gate 테스트

### 4.1 정상 배포

입력:

```text
Prometheus firing alert 없음
rollout status success
Argo CD sync healthy
```

기대 결과:

```text
Quality Gate pass
GitHub Actions job success
Slack failure alert 미전송
EventBridge event 미발행
```

### 4.2 실패 배포

입력:

```text
BackendHighErrorRate firing
BackendHighLatency firing
```

기대 결과:

```text
Quality Gate fail
GitHub Actions job failed
Slack 1차 알림 전송
EventBridge DeploymentFailed event 발행
```

## 5. EventBridge Schema 테스트

검증 항목:

```text
required field 존재
service/environment/deploymentId 형식
alerts 배열 구조
commitSha/imageTag 포함
grafanaLinks 포함
timestamp ISO-8601 형식
```

실패해야 하는 케이스:

```text
deploymentId 없음
alerts가 문자열로 전달됨
failedAt 형식 오류
environment 값이 dev/prod 외 값
```

## 6. Lambda Orchestrator 테스트

Unit test:

```text
event validation
analysis context 생성
query template 로딩
S3 path 생성
status transition
```

Integration test:

```text
sample EventBridge event로 Lambda handler 실행
Athena mock 결과를 summary JSON으로 변환
S3 mock에 event/summary/status 저장
AI Agent mock 호출
Slack mock 호출
```

## 7. Athena Query 테스트

검증 항목:

```text
SQL syntax valid
parameter rendering valid
time window 조건 포함
partition filter 포함
query result column이 summary builder와 호환
```

성능 기준:

```text
MVP query는 2분 이내 완료
partition filter 없이 전체 scan 금지
query result는 필요한 column만 반환
```

## 8. AI Agent 테스트

입력 fixture:

```text
high error rate case
high latency case
pod restart case
db connection error case
waf blocked request case
insufficient evidence case
```

검증 항목:

```text
JSON schema 통과
recommendedAction.type이 허용값 중 하나
requiresApproval이 true
evidence가 입력 데이터에 존재하는 내용만 참조
confidence가 high/medium/low 중 하나
Slack message가 생성됨
```

## 9. Slack 메시지 테스트

검증 항목:

```text
서비스명과 환경 표시
배포 ID 표시
원인 후보 표시
추천 조치 표시
Grafana/Argo CD 링크 포함
민감 정보 미포함
메시지 길이 제한 준수
```

## 10. E2E 시나리오

### Scenario A. 정상 배포

```text
GitHub Actions CD 실행
Argo CD sync 성공
rollout 성공
Prometheus alert 없음
CD 성공
```

### Scenario B. Error Rate 증가

```text
GitHub Actions CD 실행
rollout 성공
Prometheus BackendHighErrorRate firing
Quality Gate 실패
Slack 1차 알림
EventBridge event
Lambda 분석
Athena ALB/Application log query
AI Agent rollback 추천
Slack 2차 알림
```

### Scenario C. 분석 일부 실패

```text
Quality Gate 실패
Athena query 일부 timeout
partial summary 생성
AI Agent가 제한된 evidence로 분석
Slack에 partial 상태 표시
```

## 11. 완료 기준

```text
MVP fixture 기반 unit test 통과
EventBridge sample payload schema validation 통과
AI Agent output schema validation 통과
Slack message snapshot test 통과
dev 환경에서 Scenario A/B 실행 가능
```

