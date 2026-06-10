# DOC-03. Goals and Scope

## 1. 목표

이 개인 파트의 목표는 다음과 같다.

```text
1. CD 배포 직후 Prometheus/Grafana 기반으로 서비스 상태를 자동 검증한다.
2. 배포 이상이 감지되면 Slack으로 즉시 알림을 보낸다.
3. Slack 알림에는 Prometheus, Grafana, Argo CD 링크를 포함한다.
4. 배포 실패 이벤트를 EventBridge로 발행한다.
5. EventBridge를 통해 Athena 로그 분석 파이프라인을 실행한다.
6. Athena가 S3 로그를 조회하고 분석 결과를 다시 S3에 저장한다.
7. AI Agent가 분석 결과와 Runbook을 기반으로 원인과 조치 방안을 판단한다.
8. AI Agent가 Slack으로 rollback, manual fix, DR 승인 등 대응 방안을 추천한다.
```

## 2. MVP 범위

시간이 제한되어 있다면 MVP는 단계적으로 나눈다.

### MVP 1차

```text
GitHub Actions CD 후 Prometheus alert 조회
firing alert가 있으면 Slack 알림
Grafana/Prometheus/Argo CD 링크 포함
GitHub Actions job 실패 처리
```

### MVP 2차

```text
배포 실패 시 EventBridge 이벤트 발행
Lambda가 이벤트 수신
Athena Query 실행
S3에 결과 저장
Slack에 분석 결과 S3 링크 전송
```

### MVP 3차

```text
AI Agent가 Athena 결과 분석
Runbook 기반 조치 추천
Slack으로 rollback/manual fix/DR 추천
```

## 3. 비범위

초기 구현에서 반드시 제외하거나 후순위로 둘 수 있는 항목은 다음과 같다.

```text
완전 자동 rollback
운영자 승인 없는 DR 전환
모든 서비스에 대한 완전한 query template
모든 보안 로그에 대한 정밀 위협 분석
장기 장애 예측 모델
```

## 4. 성공 기준

### CD Quality Gate 성공 기준

```text
정상 배포 시 CD job이 성공한다.
비정상 배포 시 CD job이 실패한다.
Prometheus firing alert를 Slack으로 전달한다.
Grafana, Prometheus, Argo CD 링크가 Slack 메시지에 포함된다.
```

### 분석 파이프라인 성공 기준

```text
DeploymentFailed 이벤트가 EventBridge에 발행된다.
EventBridge Rule이 Lambda를 실행한다.
Lambda가 Athena Query를 실행한다.
Athena 결과가 S3에 저장된다.
AI Agent가 분석 결과와 Runbook을 기반으로 대응 방안을 생성한다.
Slack 2차 알림이 전송된다.
```

