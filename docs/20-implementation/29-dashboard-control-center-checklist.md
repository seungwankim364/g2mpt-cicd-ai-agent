# DOC-34. Dashboard Control Center Checklist

이 문서는 `dashboard/`를 단순 화면이 아니라 운영 콘솔로 확장하기 위한 체크리스트다.

## 1. 완료된 항목

```text
[x] dashboard/ 정적 UI 추가
[x] Deployment Timeline 화면 추가
[x] Quality Gate 5분 Health Window 화면 추가
[x] Backend/EKS/Redis/SQS/GPU alert coverage 화면 추가
[x] Bedrock AI Incident Analysis 화면 추가
[x] Approval & Action 상태 화면 추가
[x] Infra & Cost 상태 화면 추가
[x] demo fixture 추가
[x] dashboard data contract JSON Schema 추가
[x] local backend server 추가
[x] GET /api/dashboard 추가
[x] GET /api/actions 추가
[x] POST /api/actions 추가
[x] POST /api/infra/apply-plan 추가
[x] POST /api/infra/destroy-plan 추가
[x] 승인 버튼을 local backend action 기록으로 연결
[x] apply/destroy plan 버튼 연결
[x] dashboard/runtime/actions.json 기록 경로 추가
[x] dashboard/runtime/ gitignore 처리
[x] scripts/test-local.sh에 dashboard 검증 추가
[x] Runtime File Role and Architecture Flow에 dashboard-control-center 반영
```

## 2. 현재 버튼 동작

현재 버튼은 실제 AWS/GitHub 작업을 바로 실행하지 않는다.

```text
Record rollback
Record dr
Record manual_fix
Record change
```

동작:

```text
브라우저 버튼 클릭
-> POST /api/actions
-> dashboard/runtime/actions.json 기록
-> 화면 latest action 갱신
```

이 방식은 로컬 개발과 발표에서 안전하다. 실제 rollback/DR/change 실행은 Slack 승인/API Gateway/EventBridge/Lambda/GitHub dispatch 경로로 검증한다.

## 3. 남은 live 연결 항목

서비스와 AWS stack이 다시 올라간 뒤 확인한다.

```text
[ ] dashboard-data.json 생성 스크립트 추가
[ ] S3 deployment-failures summary에서 dashboard data 생성
[ ] EventBridge/Lambda 실행 결과를 dashboard data에 반영
[ ] GitHub Actions API로 workflow run status 조회
[ ] Prometheus API로 현재 alert/metric 조회
[ ] Terraform output에서 slack_interactivity_url, event_bus_name, result_bucket_name 반영
[ ] Slack 승인 버튼 실제 클릭 후 dashboard action history와 대조
[ ] live mode에서 demo fallback 없이 운영 데이터 표시
```

## 4. 실행 명령

```bash
node dashboard/server.mjs
```

브라우저:

```text
http://localhost:5173
```

정적 demo fallback:

```text
http://localhost:5173?mode=demo
```

파일 기반 live adapter:

```text
http://localhost:5173?mode=live
```

## 5. 관련 파일

```text
dashboard/server.mjs
dashboard/index.html
dashboard/src/main.js
dashboard/src/styles.css
dashboard/src/data/loadDashboardData.js
dashboard/src/data/sample-dashboard.js
dashboard/data-contracts/dashboard-data.schema.json
dashboard/runtime/actions.json
```
