# DOC-01. Old vs New

## 목적

기존 CD 구조와 개선된 Monitoring-driven CD Quality Gate 구조의 차이를 명확히 구분한다.

## Old. 기존 CI/CD 구조

기존 CI/CD 파이프라인은 보통 다음 단계에서 끝난다.

```text
코드 Push
  -> GitHub Actions 실행
  -> Docker Image Build
  -> ECR Push
  -> GitOps Repository의 Image Tag 수정
  -> Argo CD Sync
  -> Kubernetes 배포
  -> 배포 완료
```

기존 구조의 성공 기준은 주로 다음과 같다.

```text
이미지가 정상적으로 빌드되었는가?
Manifest가 정상적으로 반영되었는가?
Pod가 생성되었는가?
Deployment rollout이 완료되었는가?
```

## Old 구조의 한계

Kubernetes에서 배포가 완료되었다고 해서 실제 서비스가 정상이라는 뜻은 아니다.

예를 들어 다음과 같은 문제가 발생할 수 있다.

```text
Pod는 Running 상태이지만 API 500 에러가 증가함
Readiness Probe는 통과하지만 특정 API 응답 속도가 급격히 느려짐
새 이미지 배포 후 Pod Restart가 반복됨
DB 연결 오류가 발생하지만 배포 자체는 성공으로 표시됨
WAF/ALB/CloudFront 로그에서는 비정상 트래픽이 증가함
사용자는 장애를 체감하지만 CI/CD는 성공으로 끝남
```

## New. 개선된 구조

개선된 구조는 기존 `gympt-ops` CI/CD가 배포를 완료한 이후 Prometheus와 Grafana를 사용해 서비스 상태를 검증한다. build, ECR push, GitOps values update, Argo CD sync는 기존 흐름을 그대로 사용하고, 그 뒤에 Quality Gate와 AI Incident Analysis를 추가한다.

```text
기존 gympt-ops CI/CD
  -> ECR Push
  -> GitOps Repository Image Tag 수정
  -> Argo CD Sync
  -> Kubernetes Rollout 완료
  -> cd-quality-gate-architecture extension
  -> Prometheus Alert / Metric 확인
  -> Grafana Dashboard URL 생성
  -> Quality Gate 판단
  -> 성공 또는 실패 처리
```

장애가 감지되면 다음 단계가 추가로 실행된다.

```text
CD Failed
  -> Slack 1차 알림
  -> EventBridge DeploymentFailed 이벤트 발행
  -> Lambda 분석 오케스트레이터 실행
  -> Athena Query 실행
  -> S3 로그 분석
  -> 분석 결과 S3 저장
  -> AI Agent 원인 분석
  -> Runbook 기반 조치 추천
  -> Slack 2차 알림
```

## 비교표

| 구분 | Old | New |
| --- | --- | --- |
| 성공 기준 | 배포 완료 | 배포 완료 + 서비스 메트릭 정상 |
| 확인 대상 | Build, Push, Sync, Rollout | Rollout, Alert, Metric, Dashboard, Logs |
| 장애 감지 | 운영자가 수동 확인 | Prometheus 기반 자동 감지 |
| 장애 알림 | 수동 또는 단순 알림 | Slack 1차 알림 + 근거 링크 포함 |
| 로그 분석 | 관리자가 직접 조회 | EventBridge -> Lambda -> Athena 자동 분석 |
| 원인 분석 | 수동 분석 | AI Agent가 원인 후보와 근거 생성 |
| 대응 판단 | 운영자 경험 의존 | Rollback / Manual Fix / DR 추천 |
| 회고 자료 | 분산됨 | S3에 분석 결과 저장 |

## 핵심 전환

```text
Before:
배포 완료 = 성공

After:
배포 완료 + 서비스 상태 정상 = 성공
```

## 설계 의도

이 구조의 핵심은 CD 파이프라인이 단순히 "배포 명령을 수행하는 자동화"에서 끝나지 않고, 실제 운영 품질을 검증하는 품질 게이트 역할까지 수행하도록 확장하는 것이다.
