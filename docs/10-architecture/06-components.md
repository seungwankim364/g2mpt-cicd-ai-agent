# DOC-06. Components

## 1. GitHub Actions

### 역할

```text
CI/CD 파이프라인 실행
Docker Image Build
ECR Push
GitOps Repository image tag 수정
Argo CD Sync 확인
배포 후 Prometheus Health Check 실행
실패 시 EventBridge 이벤트 발행
```

### 추가할 Job

```text
post-deploy-health-check
```

### 수행 작업

```text
kubectl rollout status 확인
Prometheus API 호출
firing alert 조회
Slack 알림 전송
EventBridge put-events 실행
```

## 2. Argo CD

### 역할

```text
GitOps Repository 변경 감지
Helm Chart 기반 Kubernetes 배포
Application Health 상태 제공
배포 상태 확인
Rollback 대상 revision 확인
```

### 활용 방식

```text
argocd app wait
argocd app get
argocd app history
argocd app rollback
```

## 3. Prometheus

### 역할

```text
서비스 메트릭 수집
PrometheusRule 기반 Alert 판단
배포 직후 상태 검증 기준 제공
```

### API

```text
/api/v1/alerts
/api/v1/query
/api/v1/query_range
```

## 4. Grafana

### 역할

```text
서비스 상태 시각화
장애 발생 시 빠른 확인 링크 제공
Athena 분석 결과 대시보드화
```

### Slack에 포함할 링크

```text
Backend Dashboard
EKS Overview Dashboard
JVM Metrics Dashboard
SQS Metrics Dashboard
Redis Metrics Dashboard
Athena Analysis Dashboard
```

## 5. Slack

### 역할

```text
배포 성공/실패 알림
장애 요약 전달
Prometheus/Grafana/Argo CD 링크 제공
AI 분석 결과 전달
운영자 승인 액션 제공
```

### 메시지 종류

```text
1차 알림: 배포 실패 감지
2차 알림: AI 분석 결과 및 조치 추천
승인 요청: Rollback / Manual Fix / DR
```

## 6. EventBridge

### 역할

```text
배포 실패 이벤트를 비동기 분석 파이프라인으로 전달
GitHub Actions와 Lambda 분석 시스템을 느슨하게 연결
```

## 7. Athena

### 역할

```text
S3에 저장된 로그를 SQL로 분석
배포 실패 시점 전후의 로그를 조회
에러 패턴, API별 장애, 보안 이벤트, 인프라 로그 분석
분석 결과를 S3에 저장
```

### 조회 대상

```text
cloudfront_access_logs
waf_alb_logs
waf_cloudfront_logs
s3_access_logs
inspector_findings
application_logs
alb_access_logs
```

## 8. S3

### 역할

```text
원본 로그 저장
Athena Query Result 저장
AI 분석 입력 데이터 저장
장애 분석 결과 저장
감사/회고용 자료 보관
```

### 저장 경로 예시

```text
s3://gympt-prod-logs-337112169365/
s3://gympt-prod-athena-results-337112169365/athena-results/
s3://gympt-prod-athena-results-337112169365/deployment-failures/
```

## 9. AI Agent

### 역할

```text
Athena 분석 결과 해석
Prometheus Alert 해석
Grafana 링크 기반 장애 맥락 제공
Runbook 검색
원인 후보 생성
조치 방안 추천
Slack 메시지 생성
```

### 입력

```text
서비스명
환경
배포 시간
이미지 태그
커밋 SHA
Prometheus Alert 목록
Athena 로그 분석 결과
Grafana Dashboard 링크
Argo CD Application 링크
Runbook 문서 또는 alert-specific shell scripts
과거 장애 기록
```

### 출력

```text
장애 요약
원인 후보
근거 로그/메트릭
영향 범위
추천 조치
Rollback 필요 여부
Manual Fix 필요 여부
DR 승인 필요 여부
```

