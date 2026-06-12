# CD Quality Gate Control Center

This dashboard is the operator view for the CD Quality Gate and AI incident analysis flow.

It runs without AWS resources by using demo data. When the stack is live, place a generated `dashboard-data.json` next to `index.html` and open with `?mode=live`.

## Open Locally

```bash
python3 -m http.server 5173 --directory dashboard
```

Then open:

```text
http://localhost:5173
```

Live adapter mode:

```text
http://localhost:5173?mode=live
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

The live adapter currently reads:

```text
dashboard/dashboard-data.json
```

The JSON contract is documented in:

```text
dashboard/data-contracts/dashboard-data.schema.json
```

Later, the same adapter boundary can be changed to call API Gateway, S3, GitHub Actions API, or Prometheus.
