# DOC-09. Implementation Plan

## Phase 1. CD Quality Gate 구현

### 목표

```text
배포 후 Prometheus 기반 자동 검증
실패 시 Slack 알림
```

### 작업

```text
1. 기존 gympt-ops 배포 이후 실행되는 Quality Gate workflow 구성
2. Argo CD automated sync 완료 이후 Kubernetes rollout 확인
3. kubectl rollout status 확인
4. Prometheus API /api/v1/alerts 조회
5. 관련 alert가 firing이면 job 실패 처리
6. Slack webhook으로 1차 알림 전송
7. Grafana/Prometheus/Argo CD 링크 포함
```

### 완료 기준

```text
정상 배포 시 CD 성공
비정상 배포 시 CD 실패
Slack으로 실패 알림 수신
메시지에 원인 alert와 dashboard 링크 포함
```

## Phase 2. EventBridge 연동

### 목표

```text
배포 실패 이벤트를 분석 파이프라인으로 전달
```

### 작업

```text
1. EventBridge custom event source 정의
2. GitHub Actions에서 aws events put-events 실행
3. detail-type을 DeploymentFailed로 설정
4. Lambda target rule 생성
5. 이벤트 payload에 서비스명, 환경, commit, image tag, alert 목록 포함
```

### 완료 기준

```text
배포 실패 시 EventBridge 이벤트 생성
EventBridge Rule이 Lambda를 실행
Lambda에서 이벤트 detail 확인 가능
```

## Phase 3. Athena 로그 분석

### 목표

```text
배포 실패 시점 기준으로 S3 로그를 자동 분석
```

### 작업

```text
1. Lambda에서 Athena StartQueryExecution 호출
2. 서비스별 분석 query template 작성
3. 배포 실패 전후 10~15분 로그 조회
4. Query result를 S3에 저장
5. 분석 summary JSON 생성
```

### 완료 기준

```text
배포 실패 이벤트 발생 시 Athena Query 자동 실행
S3에 분석 결과 저장
Slack에 Athena 결과 링크 포함 가능
```

## Phase 4. AI Agent 분석

### 목표

```text
Athena 결과와 Runbook을 기반으로 조치 방안 추천
```

### 작업

```text
1. AI Agent 입력 포맷 정의
2. Athena summary JSON 읽기
3. Prometheus alert 정보 결합
4. Runbook 문서 또는 alert-specific shell scripts 검색
5. 원인 후보 생성
6. rollback/manual fix/DR 중 추천
7. Slack 2차 알림 생성
```

### 완료 기준

```text
AI가 장애 요약 생성
원인 후보와 근거 제시
추천 조치 생성
Slack으로 분석 결과 전송
```

## Phase 5. 승인 기반 대응

### 목표

```text
운영자가 Slack에서 승인하면 rollback 또는 runbook 실행
```

### 작업

```text
1. Slack interactive button 또는 승인 workflow 설계
2. Approve Rollback 이벤트 처리
3. Argo CD rollback 또는 GitOps image tag rollback 수행
4. Rollback 후 다시 Prometheus Health Check 실행
5. 결과 Slack 알림
```

### 완료 기준

```text
관리자 승인 후 rollback 가능
rollback 결과 자동 검증
성공/실패 Slack 알림
```
