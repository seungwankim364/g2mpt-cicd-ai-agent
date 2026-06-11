# DOC-05. Detailed Flows

## 1. 정상 배포 흐름

```text
1. 개발자가 기존 `gympt-ops` app repository에 코드를 push하거나 prod 배포 PR을 승인한다.
2. 기존 GitHub Actions가 build/test를 수행한다.
3. 기존 GitHub Actions가 Docker image를 생성하고 ECR에 push한다.
4. 기존 GitHub Actions가 GitOps repository의 `values-dev.yaml` 또는 `values-prod.yaml` image tag를 갱신한다.
5. Argo CD가 GitOps repository 변경을 감지한다.
6. Argo CD automated sync가 EKS `gympt-prod/backend-api-prod`에 배포한다.
7. 여기서부터 이 저장소의 CD Quality Gate 확장 흐름이 시작된다.
8. Quality Gate workflow가 EKS/VPC 내부 self-hosted runner에서 실행된다.
9. Kubernetes rollout status를 확인한다.
10. 내부 Prometheus API를 호출하여 관련 alert 상태를 확인한다.
11. backend-api 대상 서비스의 메트릭을 확인한다.
12. 문제가 없으면 Quality Gate를 성공 처리한다.
13. Slack `#cd-deploy-alarm`으로 배포 완료 메시지를 보낸다.
```

## 2. 배포 실패 흐름

```text
1. 새 버전이 배포된다.
2. 배포 직후 5분 동안 Health Check Window를 둔다.
3. self-hosted runner가 내부 Prometheus에서 firing 중인 alert를 조회한다.
4. 다음과 같은 문제가 감지된다.
   - 5xx Error Rate 증가
   - p95 Latency 증가
   - Pod Restart 증가
   - Deployment Unavailable Replicas 발생
   - Readiness Probe 실패
5. GitHub Actions job을 실패 처리한다.
6. Slack으로 1차 알림을 보낸다.
7. Slack 메시지에 Grafana, Prometheus, Argo CD, GitHub Actions 링크를 포함한다.
8. EventBridge에 DeploymentFailed 이벤트를 발행한다.
9. EventBridge Rule이 Lambda 분석 오케스트레이터를 실행한다.
10. Lambda가 Athena Query를 실행한다.
11. Athena가 S3 로그를 분석한다.
12. 분석 결과를 S3에 저장한다.
13. AI Agent가 분석 결과를 읽는다.
14. AI Agent가 원인 후보와 대응 방안을 생성한다.
15. Slack으로 2차 분석 결과를 보낸다.
```

## 3. AI 분석 흐름

```text
1. Lambda가 DeploymentFailed 이벤트 detail을 읽는다.
2. 서비스명, 환경, 배포 시간, image tag, commit SHA를 추출한다.
3. 실패 시점 전후의 Athena query window를 계산한다.
4. 서비스별 query template을 선택한다.
5. Athena StartQueryExecution을 호출한다.
6. Query result를 S3에 저장한다.
7. Lambda가 summary JSON을 생성한다.
8. AI Agent가 summary JSON, Prometheus alert, Runbook을 읽는다.
9. AI Agent가 장애 원인 후보를 생성한다.
10. AI Agent가 rollback/manual fix/DR 중 추천 조치를 선택한다.
11. Slack 2차 메시지를 생성한다.
```

## 4. 승인 기반 대응 흐름

```text
1. Slack 2차 알림에 추천 조치가 포함된다.
2. 운영자가 rollback/manual fix/DR 중 하나를 검토한다.
3. 운영자가 승인하면 후속 workflow가 실행된다.
4. Rollback인 경우 Argo CD rollback 또는 GitOps image tag rollback을 수행한다.
5. Manual Fix인 경우 담당자가 설정 또는 코드를 수정한다.
6. DR인 경우 승인된 Runbook을 실행한다.
7. 조치 후 Prometheus Health Check를 다시 실행한다.
8. 결과를 Slack으로 다시 알린다.
```
