# DOC-11. Presentation Notes

## 1. 발표 시작 문장

제가 맡은 파트는 Prometheus와 Grafana를 CD 파이프라인에 연결해서, 배포가 끝난 뒤 실제 서비스가 정상인지 자동으로 검증하는 구조입니다.

기존에는 Kubernetes rollout이 완료되면 CD가 성공으로 끝났지만, 실제 운영에서는 Pod가 Running이어도 5xx 에러가 증가하거나 특정 API latency가 급증할 수 있습니다.

그래서 저는 배포 완료를 성공으로 보지 않고, 배포 완료 이후 Prometheus alert와 주요 metric이 정상일 때만 성공으로 판단하는 CD Quality Gate를 설계했습니다.

## 2. Old vs New 설명

기존 구조는 다음과 같습니다.

```text
GitHub Actions
  -> ECR Push
  -> GitOps image tag 변경
  -> Argo CD Sync
  -> Kubernetes 배포 완료
```

이 구조의 문제는 "배포 완료"와 "서비스 정상"이 분리되어 있다는 점입니다.

개선 구조는 다음과 같습니다.

```text
GitHub Actions
  -> Argo CD Sync
  -> Kubernetes Rollout
  -> Prometheus API 조회
  -> Grafana Dashboard 링크 생성
  -> Quality Gate 판단
```

즉, 배포 이후 실제 서비스 metric까지 확인해서 CD 성공 여부를 결정합니다.

## 3. 실패 시 흐름 설명

배포 직후 Prometheus에서 firing alert가 감지되면 GitHub Actions job은 실패 처리됩니다.

동시에 Slack으로 1차 알림을 보내고, 이 알림에는 Grafana, Prometheus, Argo CD, GitHub Actions 링크가 포함됩니다.

그 다음 EventBridge에 `DeploymentFailed` 이벤트를 발행합니다.

이 이벤트가 Lambda 분석 오케스트레이터를 실행하고, Lambda는 Athena query를 통해 S3에 저장된 ALB, WAF, CloudFront, application log를 분석합니다.

분석 결과는 다시 S3에 summary JSON으로 저장되고, AI Agent가 이 결과와 Runbook을 기반으로 원인 후보와 조치 방안을 생성합니다.

## 4. AI Agent 설명

AI Agent는 단순히 "장애가 발생했다"라고 알려주는 역할이 아닙니다.

입력으로 다음 정보를 받습니다.

```text
Prometheus Alert
Athena 로그 분석 결과
Grafana Dashboard 링크
Argo CD Application 링크
Runbook 또는 alert-specific shell scripts
배포 시간, commit SHA, image tag
```

그리고 다음을 판단합니다.

```text
이 장애가 새 배포 때문에 발생했는가?
특정 API에 집중된 문제인가?
로그상 반복되는 에러 패턴이 있는가?
Rollback이 적절한가?
Manual Fix가 적절한가?
DR 승인이 필요한가?
```

## 5. Runbook 설명

Runbook은 alert별 대응 절차입니다.

예를 들어 `BackendHighErrorRate` 알람이면 ALB 5xx, application log, 최근 배포 버전, DB timeout을 확인하는 shell script나 운영 절차를 연결할 수 있습니다.

다이어그램에서는 `Runbook / Alert-specific shell scripts`가 AI Agent로 들어갑니다.

이는 AI Agent가 임의로 대응을 생성하는 것이 아니라, 사전에 정의된 운영 절차와 로그 분석 결과를 함께 참고한다는 의미입니다.

## 6. 마무리 문장

이 구조의 핵심은 CD와 Monitoring, 그리고 AI 분석을 하나의 운영 흐름으로 연결하는 것입니다.

배포 실패를 사람이 늦게 발견하는 구조에서, 시스템이 자동으로 감지하고 분석하며, 관리자에게 근거 기반 대응 방안을 제시하는 구조로 개선합니다.

