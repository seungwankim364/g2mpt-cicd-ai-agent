# DOC-05. Detailed Flows

## 1. 정상 배포 흐름

```text
1. 개발자가 main 또는 dev 브랜치에 코드를 push한다.
2. GitHub Actions가 Docker Image를 빌드한다.
3. Image를 ECR에 push한다.
4. GitHub Actions가 `GITOPS_PAT`로 `hj-3/gympt-gitops` main branch를 checkout한다.
5. `charts/backend-api/values-prod.yaml`의 `.image.tag`를 새 tag로 수정한다.
6. GitOps 변경 commit을 main branch에 직접 push한다.
7. Argo CD `backend-api-prod` Application이 Git 변경을 감지한다.
8. Argo CD automated sync가 EKS `gympt-prod/backend-api-prod`에 배포한다.
9. Quality Gate workflow가 EKS/VPC 내부 self-hosted runner에서 실행된다.
10. Kubernetes rollout status를 확인한다.
11. 내부 Prometheus API를 호출하여 관련 alert 상태를 확인한다.
12. backend-api 대상 서비스의 메트릭을 확인한다.
13. 문제가 없으면 CD job을 성공 처리한다.
14. Slack `#cicd-deploy-alarm`으로 배포 완료 메시지를 보낸다.
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
