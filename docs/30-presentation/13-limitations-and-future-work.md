# DOC-29. Limitations and Future Work

## 1. 목적

MVP 설계의 한계와 향후 확장 방향을 정리한다. 발표 질의응답에서 현실적인 범위와 발전 가능성을 설명하기 위한 문서다.

## 2. MVP 한계

```text
Prometheus alert 품질에 Quality Gate 정확도가 의존함
Athena query가 늦으면 AI 분석도 지연됨
AI Agent 추천은 evidence 품질에 따라 달라짐
자동 rollback은 승인 workflow 없이는 실행하지 않음
모든 서비스 유형을 처음부터 포괄하지 않음
```

## 3. Monitoring 한계

Prometheus 기반 Quality Gate는 metric이 충분히 정의되어 있어야 효과적이다.

한계:

```text
metric label 표준화가 부족하면 서비스별 비교가 어려움
alert threshold가 부정확하면 false positive/false negative 발생
배포 직후 metric 안정화 시간이 필요함
```

개선 방향:

```text
서비스별 SLI/SLO 정리
공통 metric label 표준화
baseline 대비 변화율 기반 판단 추가
canary 배포와 연계
```

## 4. Log Analysis 한계

Athena 분석은 S3에 로그가 적재된 이후에만 가능하다.

한계:

```text
로그 적재 지연 발생 가능
SQL query 비용과 실행 시간이 증가할 수 있음
로그 schema가 바뀌면 query가 깨질 수 있음
application log 품질에 따라 분석 깊이가 달라짐
```

개선 방향:

```text
partition 전략 강화
query template versioning
OpenTelemetry trace 연계
로그 schema validation 추가
```

## 5. AI Agent 한계

AI Agent는 제공된 evidence를 기반으로 판단한다.

한계:

```text
없는 정보를 추론할 위험
원인 후보 confidence가 항상 정답을 의미하지 않음
민감 정보 필터링이 선행되어야 함
운영자 승인 없이 조치 실행 불가
```

개선 방향:

```text
strict output schema 적용
evidence-only prompt 강화
recommendation feedback 저장
postmortem 결과를 runbook에 반영
```

## 6. Rollback 한계

Rollback은 모든 장애의 정답이 아니다.

Rollback이 어려운 경우:

```text
DB migration이 backward incompatible
외부 dependency 장애
feature flag/config 문제
이미 데이터 변경이 발생한 경우
인프라 capacity 문제
```

개선 방향:

```text
pre-deploy rollback safety check
DB migration compatibility checklist
feature flag rollback 연계
progressive delivery 도입
```

## 7. 향후 확장 방향

### 7.1 Canary Analysis

```text
전체 배포 전에 일부 traffic만 새 버전으로 전환
canary와 stable metric 비교
문제 감지 시 자동 중단
```

### 7.2 SLO 기반 Quality Gate

```text
단일 alert가 아니라 서비스 SLO burn rate 기준으로 판단
critical user journey 중심 검증
```

### 7.3 Trace 기반 원인 분석

```text
OpenTelemetry trace id를 Athena summary와 연결
느린 span, error span, dependency call 분석
```

### 7.4 Automated Runbook Execution

```text
승인된 runbook만 자동 실행
실행 전 dry-run
실행 결과 재검증
```

### 7.5 Feedback Loop

```text
AI 추천 결과와 실제 조치 결과 비교
정확한 추천은 runbook에 반영
틀린 추천은 prompt와 rule 개선에 사용
```

## 8. 발표용 답변 포인트

질문: AI가 잘못 판단하면 어떻게 하나?

```text
AI는 자동 실행자가 아니라 분석 보조자입니다. 추천 조치는 evidence와 함께 제시되고, rollback 같은 작업은 운영자 승인 후에만 실행됩니다.
```

질문: false positive가 많으면 CD가 자주 막히지 않나?

```text
서비스별 threshold와 안정화 대기 시간을 설정하고, warning과 critical을 분리해서 critical 조건만 CD 실패로 처리할 수 있습니다.
```

질문: Athena 분석이 늦으면 의미가 없지 않나?

```text
1차 Slack 알림은 즉시 보내고, Athena와 AI 분석은 비동기로 수행합니다. 즉시 대응과 심층 분석을 분리한 구조입니다.
```

## 9. 최종 확장 목표

```text
배포
  -> 자동 품질 검증
  -> 이상 감지
  -> 증거 수집
  -> 원인 후보 생성
  -> 승인 기반 조치
  -> 재검증
  -> 학습/개선
```

최종 목표는 CD를 단순 배포 자동화가 아니라 운영 피드백까지 포함하는 self-healing에 가까운 배포 관리 체계로 확장하는 것이다.

