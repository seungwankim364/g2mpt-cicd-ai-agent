# CD Quality Gate Control Center

This dashboard is the operator view for the CD Quality Gate and AI incident analysis flow.

It runs without AWS resources by using demo data. When the AWS dashboard stack is enabled, the frontend calls the Dashboard API Lambda through API Gateway and CloudFront.

## Open With Backend

```bash
node dashboard/server.mjs
```

Then open:

```text
http://localhost:5173
```

The backend serves the static dashboard and local APIs:

```text
GET  /api/dashboard
GET  /api/actions
POST /api/actions
POST /api/infra/apply-plan
POST /api/infra/destroy-plan
```

Action records are written to:

```text
dashboard/runtime/actions.json
```

The local backend uses demo data and local action records. It does not call GitHub, Argo CD, or Prometheus.

## AWS Live Mode

When Terraform is applied with the dashboard enabled, the Dashboard API Lambda serves:

```text
GET  /api/dashboard
GET  /api/actions
POST /api/actions
GET  /api/status
```

The Lambda attempts live reads from:

```text
GitHub Actions API
-> latest hj-3/gympt-app backend-api-ci.yml workflow runs

Argo CD API
-> backend-api-prod sync and health status

Prometheus API
-> current firing alerts from /api/v1/alerts
```

If a token, network path, or service is unavailable, the dashboard does not fail the whole page. It marks that integration as `unavailable` and shows the reason in the Live CI/CD & Monitoring section.

Required Terraform/environment inputs:

```text
github_token_secret_arn
-> GitHub token used for private repo workflow run reads

dashboard_argocd_url
-> Argo CD base URL, default https://argocd.g2mpt.com

dashboard_argocd_token_secret_arn
-> optional Argo CD API token secret ARN

dashboard_prometheus_url
-> Prometheus base URL, default internal kube-prometheus-stack service URL
```

Important network note:

```text
GitHub API is public internet reachable.
Argo CD API works only if the URL is reachable from Lambda and the token is valid.
The default Prometheus URL is an in-cluster Kubernetes service address, so a normal public Lambda cannot reach it unless networking is changed, Prometheus is exposed through a controlled endpoint, or the dashboard Lambda is placed where it can reach the cluster network.
```

## Static Demo Mode

```bash
python3 -m http.server 5173 --directory dashboard
```

Then open:

```text
http://localhost:5173?mode=demo
```

## Data Contract

The screen expects:

```text
deployment
timeline
healthWindow
alertGroups
links
live
analysis
approvals
infra
```

Demo data lives in:

```text
dashboard/src/data/sample-dashboard.js
```

The file-based live adapter still reads:

```text
dashboard/dashboard-data.json
```

The JSON contract is documented in:

```text
dashboard/data-contracts/dashboard-data.schema.json
```

The AWS live adapter is implemented in:

```text
lambda/dashboard-api/app.py
```
