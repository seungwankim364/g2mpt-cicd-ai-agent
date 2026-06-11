# DOC-00. Overview

## 주제명

**Monitoring-driven CD Quality Gate with AI Incident Analysis**

## 한글명

**Prometheus 기반 CD 배포 검증 및 AI 장애 분석 파이프라인 / 사이트**

## 발표용 한 문장

Prometheus와 Grafana를 CD 파이프라인의 품질 게이트로 사용하고, 배포 실패 시 EventBridge, Athena, S3, AI Agent를 통해 자동 원인 분석과 대응 추천까지 연결하는 운영 자동화 시스템을 구현한다.

## 핵심 정의

이 개인 파트는 단순히 PrometheusRule을 추가하는 작업이 아니다.

핵심은 다음과 같다.

```text
CI/CD와 Monitoring을 연결해서
배포 직후 서비스 상태를 자동으로 검증하고,
실패 시 EventBridge를 통해 로그 분석 파이프라인을 실행하며,
AI Agent가 원인과 대응 방안을 추천하도록 만드는 것
```

## 최종 목표

```text
배포 실패를 사람이 늦게 발견하는 구조에서,
시스템이 자동으로 감지하고 분석하며,
관리자에게 근거 기반 대응 방안을 제시하는 구조로 개선한다.
```

## 전체 구조

전체 구조는 크게 두 단계로 나뉜다.

```text
1단계: CD Quality Gate
2단계: AI Incident Analysis Pipeline
```

## 주요 흐름

```text
Existing gympt-ops CI/CD
  -> build/test/ECR push/GitOps values update
  -> Argo CD automated sync
  -> Kubernetes Rollout 완료
  -> CD Quality Gate extension 시작
  -> Prometheus API 조회
  -> Grafana Dashboard URL 생성
  -> Quality Gate 판단
  -> 성공 또는 실패 처리
```

실패 시:

```text
Slack 1차 알림
  -> EventBridge DeploymentFailed 이벤트
  -> Lambda 분석 오케스트레이터
  -> Athena S3 로그 분석
  -> AI Agent 원인 분석
  -> Runbook 기반 조치 추천
  -> Slack 2차 알림
```

## 주요 산출물

| 산출물 | 설명 |
| --- | --- |
| Architecture Diagram | 전체 흐름을 시각화한 draw.io 다이어그램 |
| CD Quality Gate 설계 | 배포 직후 Prometheus 기반 검증 설계 |
| EventBridge Payload | 배포 실패 이벤트 스키마 |
| Athena Analysis 설계 | S3 로그 분석 대상과 query 구조 |
| AI Agent 설계 | 분석 입력, 출력, 추천 판단 구조 |
| Slack Message 설계 | 1차 실패 알림과 2차 AI 분석 알림 |
