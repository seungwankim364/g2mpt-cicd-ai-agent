# CD Quality Gate Control Center

This dashboard is the operator view for the CD Quality Gate and AI incident analysis flow.

It runs without AWS resources by using demo data. When the stack is live, place a generated `dashboard-data.json` next to `index.html` and open with `?mode=live`.

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
analysis
approvals
infra
```

Demo data lives in:

```text
dashboard/src/data/sample-dashboard.js
```

The file-based live adapter reads:

```text
dashboard/dashboard-data.json
```

The JSON contract is documented in:

```text
dashboard/data-contracts/dashboard-data.schema.json
```

Later, the same adapter boundary can be changed to call API Gateway, S3, GitHub Actions API, or Prometheus.
