# DOC-02. Background and Problems

## 1. 배경

기존 CI/CD 파이프라인은 배포 자동화에는 강하지만, 배포 이후 실제 서비스 품질을 판단하는 데에는 한계가 있다.

Kubernetes의 rollout이 완료되었다는 것은 다음을 의미한다.

```text
Deployment가 새 ReplicaSet을 생성했다.
Pod가 스케줄링되었다.
컨테이너가 실행되었다.
Kubernetes 관점의 rollout 조건을 만족했다.
```

하지만 이것이 곧 다음을 보장하지는 않는다.

```text
사용자 API가 정상 응답한다.
5xx Error Rate가 안정적이다.
p95 Latency가 정상 범위다.
DB 연결이 정상이다.
특정 API path가 정상 동작한다.
보안/인프라 로그에 비정상 이벤트가 없다.
```

따라서 단순히 "배포가 되었는가"가 아니라, **배포 이후 서비스가 실제로 정상 동작하는가**를 자동으로 검증하는 과정이 필요하다.

## 2. 문제 정의

### 2.1 배포 성공과 서비스 정상 여부가 분리되어 있음

GitHub Actions나 Argo CD는 주로 다음을 확인한다.

```text
이미지가 정상적으로 빌드되었는가?
Manifest가 정상적으로 반영되었는가?
Pod가 생성되었는가?
Deployment rollout이 완료되었는가?
```

하지만 다음과 같은 서비스 품질 문제까지 자동 판단하지는 못한다.

```text
5xx Error Rate 증가
p95 Latency 증가
Pod Restart 증가
Readiness/Liveness Probe 실패 증가
특정 API 장애
배포 직후 보안 이벤트 증가
```

### 2.2 장애 발생 시 원인 분석이 수동적임

배포 실패나 장애가 발생하면 관리자가 직접 다음 작업을 해야 한다.

```text
Grafana Dashboard 확인
Prometheus Alert 확인
CloudWatch Logs 확인
S3 로그 확인
Athena Query 실행
Runbook 확인
Rollback 여부 판단
Slack으로 공유
```

이 과정은 시간이 오래 걸리고, 장애 초기에 대응이 늦어질 수 있다.

### 2.3 자동화된 대응 판단이 부족함

장애 발생 시 항상 rollback이 정답은 아니다.

상황에 따라 대응은 달라져야 한다.

```text
새 버전 배포 직후 에러 증가 -> Rollback 권장
설정값 누락 -> Manual Fix 권장
DB 장애 또는 인프라 장애 -> DR 또는 운영자 승인 기반 복구 권장
보안 이벤트 증가 -> WAF/Inspector 분석 필요
```

따라서 로그와 메트릭을 기반으로 "어떤 대응이 적절한지" 판단해주는 분석 체계가 필요하다.

## 3. 해결 방향

이 시스템은 다음 세 가지를 연결한다.

```text
CD Pipeline
  + Monitoring
  + AI Incident Analysis
```

결과적으로 CD는 단순 배포 자동화가 아니라 운영 품질 검증과 장애 대응 판단의 시작점이 된다.

