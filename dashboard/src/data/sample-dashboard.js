export const sampleDashboard = {
  mode: "demo",
  generatedAt: "2026-06-12T15:30:00+09:00",
  deployment: {
    id: "backend-api-prod-20260612-1530",
    service: "backend-api",
    environment: "prod",
    namespace: "gympt-prod",
    imageTag: "backend-api:abc1234",
    rollbackImageTag: "backend-api:def5678",
    commitSha: "abc1234",
    branch: "main",
    repository: "hj-3/gympt-app",
    argocdApp: "backend-api-prod",
    status: "blocked",
    startedAt: "2026-06-12T15:18:00+09:00",
    lastUpdatedAt: "2026-06-12T15:30:00+09:00"
  },
  timeline: [
    { id: "push", label: "GitHub push", owner: "gympt-app", status: "complete", at: "15:18", detail: "main branch image build started" },
    { id: "ecr", label: "ECR push", owner: "GitHub Actions", status: "complete", at: "15:20", detail: "backend-api:abc1234 pushed" },
    { id: "gitops", label: "GitOps update", owner: "gympt-gitops", status: "complete", at: "15:21", detail: "values image tag updated" },
    { id: "argocd", label: "Argo CD sync", owner: "Argo CD", status: "complete", at: "15:23", detail: "backend-api-prod synced" },
    { id: "gate", label: "Quality Gate", owner: "cd-quality-gate", status: "failed", at: "15:28", detail: "5 minute health window failed" },
    { id: "event", label: "DeploymentFailed", owner: "EventBridge", status: "complete", at: "15:28", detail: "event published to cd-quality-gate-prod-bus" },
    { id: "ai", label: "Bedrock analysis", owner: "Lambda", status: "complete", at: "15:29", detail: "increase_memory recommended" },
    { id: "approval", label: "Approval action", owner: "Slack", status: "waiting", at: "now", detail: "operator decision pending" },
    { id: "redeploy", label: "Redeploy and verify", owner: "gympt-app", status: "pending", at: "-", detail: "runs after approved action" }
  ],
  healthWindow: {
    durationSeconds: 300,
    intervalSeconds: 60,
    result: "failed",
    samples: [
      { sample: 1, at: "15:24", result: "warning", alerts: 2, latencyMs: 940 },
      { sample: 2, at: "15:25", result: "failed", alerts: 3, latencyMs: 1320 },
      { sample: 3, at: "15:26", result: "failed", alerts: 5, latencyMs: 1620 },
      { sample: 4, at: "15:27", result: "failed", alerts: 6, latencyMs: 1860 },
      { sample: 5, at: "15:28", result: "failed", alerts: 6, latencyMs: 2020 }
    ],
    metrics: {
      errorRate: 8.4,
      p95LatencySeconds: 2.8,
      podRestartIncrease: 3,
      dbPoolUsageRatio: 0.93,
      jvmHeapUsageRatio: 0.72
    }
  },
  alertGroups: [
    {
      name: "Backend",
      severity: "critical",
      count: 3,
      dashboards: ["api-latency", "jvm-metrics"],
      alerts: [
        { name: "BackendHighErrorRate", severity: "critical", summary: "Backend API error rate is above threshold", value: "8.2%" },
        { name: "BackendHighLatency", severity: "warning", summary: "Backend API p95 latency is high", value: "1450ms" },
        { name: "BackendDBPoolExhaustion", severity: "critical", summary: "Database connection pool near exhaustion", value: "93%" }
      ]
    },
    {
      name: "Platform",
      severity: "warning",
      count: 1,
      dashboards: ["eks-overview"],
      alerts: [
        { name: "PodRestartFrequent", severity: "warning", summary: "Pod restart count increased during rollout", value: "+3" }
      ]
    },
    {
      name: "Data plane",
      severity: "critical",
      count: 2,
      dashboards: ["redis-metrics", "sqs-metrics"],
      alerts: [
        { name: "SQSMessageAge", severity: "critical", summary: "SQS queue has old messages", value: "2400s" },
        { name: "RedisConnectionError", severity: "critical", summary: "Redis has no connected clients", value: "0" }
      ]
    },
    {
      name: "AI workload",
      severity: "critical",
      count: 1,
      dashboards: ["gpu-metrics"],
      alerts: [
        { name: "GPUMemoryHigh", severity: "critical", summary: "GPU memory usage is high", value: "95%" }
      ]
    }
  ],
  links: {
    grafana: "https://grafana.g2mpt.com",
    prometheus: "http://kube-prometheus-stack-prometheus.monitoring.svc:9090",
    argocd: "https://argocd.g2mpt.com/applications/backend-api-prod",
    githubRun: "https://github.com/hj-3/gympt-app/actions",
    slackChannel: "#cd-deploy-alarm"
  },
  analysis: {
    engine: "Amazon Bedrock",
    model: "anthropic.claude-3-haiku-20240307-v1:0",
    confidence: 0.82,
    recommendedAction: "increase_memory",
    severity: "critical",
    summary: "The failure started immediately after the backend-api image tag changed. Error rate, latency, and DB pool pressure increased together during the post-deploy window.",
    causeCandidates: [
      { title: "New backend image regression", score: 0.82, evidence: "Error rate and latency rose after Argo CD sync." },
      { title: "Database pool saturation", score: 0.68, evidence: "BackendDBPoolExhaustion fired at 93% usage." },
      { title: "Queue backlog spillover", score: 0.41, evidence: "SQS message age exceeded threshold after API errors." }
    ],
    nextSteps: [
      "Approve increase_memory if heap pressure continues.",
      "Check API latency and JVM dashboard during the GitOps patch.",
      "Keep rollback as fallback if error rate continues after the runbook."
    ]
  },
  approvals: [
    { action: "rollback", status: "waiting", approver: "-", target: "backend-api:def5678", workflow: "rollback.yml", repo: "seungwankim364/g2mpt-cicd-ai-agent", detail: "updates hj-3/gympt-gitops values tag directly" },
    { action: "restart_deployment", status: "available", approver: "-", target: "pod annotation bump", workflow: "change-apply.yml", repo: "seungwankim364/g2mpt-cicd-ai-agent" },
    { action: "scale_replicas", status: "available", approver: "-", target: "autoscaling.minReplicas=2", workflow: "change-apply.yml", repo: "seungwankim364/g2mpt-cicd-ai-agent" },
    { action: "increase_memory", status: "available", approver: "-", target: "memory request/limit", workflow: "change-apply.yml", repo: "seungwankim364/g2mpt-cicd-ai-agent" },
    { action: "increase_hpa", status: "available", approver: "-", target: "autoscaling.maxReplicas=30", workflow: "change-apply.yml", repo: "seungwankim364/g2mpt-cicd-ai-agent" },
    { action: "open_fix_issue", status: "available", approver: "-", target: "fix issue", workflow: "manual-fix.yml", repo: "seungwankim364/g2mpt-cicd-ai-agent" },
    { action: "dr", status: "available", approver: "-", target: "configured DR GitOps patch", workflow: "dr-failover.yml", repo: "seungwankim364/g2mpt-cicd-ai-agent" }
  ],
  infra: {
    terraformState: "destroyed",
    lastApply: "2026-06-12T14:56:00+09:00",
    lastDestroy: "2026-06-12T15:11:00+09:00",
    resources: [
      { name: "Lambda", status: "destroyed", count: 3 },
      { name: "EventBridge", status: "destroyed", count: 3 },
      { name: "S3 result bucket", status: "destroyed", count: 1 },
      { name: "Athena", status: "destroyed", count: 2 },
      { name: "API Gateway", status: "destroyed", count: 1 },
      { name: "Secrets Manager", status: "preserved", count: 3 }
    ],
    checklist: [
      { label: "Lambda zip packaged", status: "complete" },
      { label: "terraform validate", status: "complete" },
      { label: "Slack signing secret ARN", status: "complete" },
      { label: "Slack interactivity URL", status: "waiting" },
      { label: "E2E service recovery test", status: "pending" }
    ]
  }
};
