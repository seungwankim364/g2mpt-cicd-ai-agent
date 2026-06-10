# DOC-10. Expected Effects

## 1. 배포 안정성 향상

기존에는 배포가 완료되면 성공으로 판단했지만, 개선 후에는 실제 서비스 메트릭까지 확인한다.

```text
Before:
배포 완료 = 성공

After:
배포 완료 + 서비스 상태 정상 = 성공
```

## 2. 장애 감지 시간 단축

배포 직후 자동으로 alert를 확인하기 때문에 장애를 빠르게 감지할 수 있다.

기존에는 운영자가 Grafana나 Prometheus를 직접 확인해야 했다.  
개선 후에는 CD job 자체가 Prometheus alert를 확인하고, firing alert가 있으면 즉시 Slack으로 알린다.

## 3. 원인 분석 자동화

Athena와 AI Agent를 통해 수동 로그 분석 시간을 줄일 수 있다.

```text
Before:
관리자가 Grafana, Prometheus, S3, Athena를 직접 확인

After:
EventBridge가 분석 파이프라인을 실행하고,
AI Agent가 원인 후보와 근거를 Slack으로 전달
```

## 4. 대응 의사결정 지원

AI가 단순 알림이 아니라 다음 중 어떤 조치가 적절한지 추천한다.

```text
Rollback
Manual Fix
DR 승인
```

## 5. 팀원 파트와 연결

이 구조는 다른 팀원들의 개인파트와도 연결된다.

```text
김형준:
GitHub, Slack, Dashboard, AWS Event 입력 기반 수정/연동

유승호:
중앙 집중 에러/보안 로그 분석 및 위협 판단 AI Agent

김민서:
RAG Runbook 기반 ops-agent 및 remediation 판단

내 파트:
배포 실패 감지, EventBridge 트리거, Athena 분석, AI 조치 추천
```

## 6. 운영 관점 기대 효과

```text
배포 직후 이상 징후 자동 감지
장애 초동 대응 속도 향상
로그 분석 반복 작업 감소
대응 판단의 근거 명확화
장애 회고 자료 자동 축적
팀원별 파트와 자연스러운 통합 가능
```

