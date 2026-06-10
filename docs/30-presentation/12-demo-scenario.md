# DOC-24. Demo Scenario

## 1. 목적

발표 또는 시연에서 CD Quality Gate와 AI Incident Analysis Pipeline의 가치를 짧은 시간 안에 보여주기 위한 demo 흐름을 정의한다.

## 2. Demo 핵심 메시지

```text
기존 CD는 배포 완료만 확인했다.
개선된 CD는 배포 이후 서비스 상태까지 검증한다.
실패하면 원인 분석과 조치 후보를 Slack으로 전달한다.
```

## 3. Demo 구성

```text
Scenario A: 정상 배포
Scenario B: 실패 배포 감지
Scenario C: AI 분석 결과 확인
Scenario D: 승인 기반 rollback 설명
```

실제 발표에서는 Scenario B와 C를 중심으로 보여준다.

## 4. 사전 준비

필요 화면:

```text
GitHub Actions workflow run
Argo CD application
Grafana dashboard
Slack channel
S3 analysis result path
Architecture diagram
```

필요 데이터:

```text
정상 Prometheus alert fixture
firing Prometheus alert fixture
EventBridge DeploymentFailed sample
Athena summary sample
AI recommendation sample
```

## 5. Scenario A. 정상 배포

흐름:

```text
1. GitHub Actions CD workflow 실행
2. Argo CD sync 성공
3. Kubernetes rollout 성공
4. Prometheus alert 조회
5. firing alert 없음
6. Quality Gate pass
7. CD success
```

보여줄 포인트:

```text
배포 성공 조건이 단순 workflow 성공이 아니라 서비스 health 기준으로 확장됨
```

발표 문장:

```text
정상 케이스에서는 배포 후 Prometheus 기준을 확인하고, 문제가 없을 때만 CD를 성공으로 종료합니다.
```

## 6. Scenario B. 실패 배포 감지

흐름:

```text
1. 새 image tag 배포
2. rollout은 성공
3. Prometheus에서 BackendHighErrorRate firing
4. Quality Gate fail
5. GitHub Actions job failed
6. Slack 1차 알림 전송
7. EventBridge DeploymentFailed event 발행
```

보여줄 포인트:

```text
Kubernetes rollout 성공과 서비스 정상은 다를 수 있음
Quality Gate가 이 차이를 잡아냄
```

발표 문장:

```text
Pod는 정상적으로 떠도 실제 요청에서 5xx가 증가하면 이 배포는 실패로 판단합니다.
```

## 7. Scenario C. AI 분석 결과

흐름:

```text
1. EventBridge가 Lambda Orchestrator 실행
2. Lambda가 Athena query 실행
3. ALB/Application log summary 생성
4. AI Agent가 Prometheus alert, Athena summary, Runbook을 결합
5. Slack 2차 알림 전송
```

보여줄 포인트:

```text
장애 발생 후 사람이 로그를 찾기 전에 분석 근거가 먼저 정리됨
원인 후보와 추천 조치가 evidence 기반으로 제공됨
```

발표 문장:

```text
실패 이벤트가 발생하면 로그 분석과 AI 분석은 비동기로 실행되고, 운영자는 Slack에서 원인 후보와 다음 조치를 바로 확인할 수 있습니다.
```

## 8. Scenario D. 승인 기반 Rollback

흐름:

```text
1. Slack 2차 알림에서 rollback 추천 확인
2. 운영자가 Approve Rollback 클릭
3. GitOps image tag를 이전 버전으로 복구
4. Argo CD sync
5. Quality Gate 재실행
6. rollback 결과 Slack 알림
```

보여줄 포인트:

```text
AI는 추천만 하고 실행은 운영자 승인 후 수행
위험한 조치를 자동으로 실행하지 않음
```

발표 문장:

```text
Rollback 같은 위험한 작업은 AI가 바로 실행하지 않고, 운영자 승인 이후에만 진행되도록 설계했습니다.
```

## 9. Demo 시간 배분

```text
문제 설명: 1분
아키텍처 설명: 2분
정상 배포 흐름: 1분
실패 감지 흐름: 2분
AI 분석 결과: 2분
마무리 효과: 1분
```

총 9분 내외로 구성한다.

## 10. 실패 대비 Plan B

실시간 demo가 실패할 경우 다음 자료로 대체한다.

```text
GitHub Actions run screenshot
Slack 1차 알림 sample
EventBridge event sample JSON
Athena summary sample JSON
Slack 2차 알림 sample
Architecture diagram
```

## 11. Demo 완료 기준

```text
배포 성공과 서비스 정상의 차이를 설명함
Quality Gate 실패 판단 기준을 보여줌
Slack 1차/2차 알림 차이를 보여줌
AI Agent가 evidence 기반으로 추천한다는 점을 보여줌
자동 조치가 아니라 승인 기반 조치라는 점을 강조함
```

