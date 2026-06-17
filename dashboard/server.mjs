import { createServer } from "node:http";
import { readFile, writeFile, mkdir } from "node:fs/promises";
import { existsSync } from "node:fs";
import { extname, join, normalize } from "node:path";
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { sampleDashboard } from "./src/data/sample-dashboard.js";

const __dirname = fileURLToPath(new URL(".", import.meta.url));
const repoRoot = normalize(join(__dirname, ".."));
const runtimeDir = join(__dirname, "runtime");
const actionLogPath = join(runtimeDir, "actions.json");
const port = Number(process.env.DASHBOARD_PORT || 5173);
const allowedActions = [
  "rollback",
  "manual_fix",
  "change",
  "restart_deployment",
  "scale_replicas",
  "increase_memory",
  "increase_hpa",
  "open_fix_issue",
  "open_change_pr"
];

const contentTypes = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".md": "text/markdown; charset=utf-8"
};

function json(res, status, body) {
  res.writeHead(status, { "Content-Type": "application/json; charset=utf-8" });
  res.end(JSON.stringify(body, null, 2));
}

async function requestBody(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  if (!chunks.length) return {};
  return JSON.parse(Buffer.concat(chunks).toString("utf-8"));
}

async function readActions() {
  if (!existsSync(actionLogPath)) return [];
  try {
    return JSON.parse(await readFile(actionLogPath, "utf-8"));
  } catch {
    return [];
  }
}

async function writeActions(actions) {
  await mkdir(runtimeDir, { recursive: true });
  await writeFile(actionLogPath, JSON.stringify(actions, null, 2) + "\n", "utf-8");
}

function terraformStateCount() {
  try {
    const output = execFileSync("terraform", ["-chdir=infra/terraform", "state", "list"], {
      cwd: repoRoot,
      encoding: "utf-8",
      stdio: ["ignore", "pipe", "ignore"]
    }).trim();
    return output ? output.split("\n").length : 0;
  } catch {
    return null;
  }
}

function systemStatus(actions) {
  return {
    backend: {
      status: "connected",
      url: `http://localhost:${port}`,
      api: "/api/dashboard"
    },
    database: {
      status: "connected",
      type: "file-json",
      path: "dashboard/runtime/actions.json",
      records: actions.length,
      initialized: existsSync(actionLogPath)
    },
    terraform: {
      status: terraformStateCount() === null ? "unavailable" : "connected",
      workingDirectory: "infra/terraform"
    }
  };
}

function commandPlan(kind) {
  if (kind === "apply") {
    return [
      "scripts/lambda/package-analysis-orchestrator.sh",
      "terraform -chdir=infra/terraform init",
      "terraform -chdir=infra/terraform fmt -check",
      "terraform -chdir=infra/terraform validate",
      "terraform -chdir=infra/terraform plan -out=tfplan",
      "terraform -chdir=infra/terraform apply tfplan"
    ];
  }
  return [
    "AWS_PROFILE_NAME=ksw2 AWS_REGION=ap-northeast-2 ENVIRONMENT=prod scripts/aws/destroy-terraform-stack.sh",
    "AWS_PROFILE_NAME=ksw2 AWS_REGION=ap-northeast-2 ENVIRONMENT=prod ALLOW_PROD=true scripts/aws/destroy-terraform-stack.sh --execute"
  ];
}

function dispatchPayload(action, base = sampleDashboard) {
  return {
    actionType: action,
    deploymentId: base.deployment.id,
    service: base.deployment.service,
    environment: base.deployment.environment,
    approvedBy: "dashboard-local",
    reason: `Approved from local dashboard for ${base.deployment.id}`,
    currentImageTag: base.deployment.imageTag,
    targetImageTag: base.deployment.rollbackImageTag || base.deployment.imageTag,
    workflow: {
      rollback: "rollback.yml",
      manual_fix: "manual-fix.yml",
      change: "change-apply.yml",
      restart_deployment: "change-apply.yml",
      scale_replicas: "change-apply.yml",
      increase_memory: "change-apply.yml",
      increase_hpa: "change-apply.yml",
      open_fix_issue: "manual-fix.yml",
      open_change_pr: "change-apply.yml"
    }[action]
  };
}

function mergeRuntime(base, actions) {
  const stateCount = terraformStateCount();
  const latestAction = actions.at(-1) || null;
  const dashboard = structuredClone(base);

  dashboard.mode = "local-backend";
  dashboard.generatedAt = new Date().toISOString();
  dashboard.actionHistory = actions;
  dashboard.latestAction = latestAction;

  if (stateCount !== null) {
    dashboard.infra.terraformState = stateCount > 0 ? "applied" : "destroyed";
    dashboard.infra.resources = dashboard.infra.resources.map((resource) => ({
      ...resource,
      status: stateCount > 0 && resource.status === "destroyed" ? "available" : resource.status
    }));
  }

  if (latestAction) {
    dashboard.approvals = dashboard.approvals.map((approval) =>
      approval.action === latestAction.action
        ? { ...approval, status: latestAction.status, approver: latestAction.approvedBy || "dashboard-local" }
        : approval
    );
    dashboard.timeline = dashboard.timeline.map((item) =>
      item.id === "approval"
        ? { ...item, status: "complete", detail: `${latestAction.action} recorded by dashboard backend`, at: latestAction.createdAt.slice(11, 16) }
        : item
    );
  }

  return dashboard;
}

async function dashboardData() {
  const actions = await readActions();
  const dashboard = mergeRuntime(sampleDashboard, actions);
  dashboard.system = systemStatus(actions);
  return dashboard;
}

async function serveStatic(req, res, pathname) {
  const safePath = pathname === "/" ? "/index.html" : pathname;
  const filePath = normalize(join(__dirname, safePath));
  if (!filePath.startsWith(__dirname)) {
    res.writeHead(403);
    res.end("Forbidden");
    return;
  }

  try {
    const body = await readFile(filePath);
    res.writeHead(200, { "Content-Type": contentTypes[extname(filePath)] || "application/octet-stream" });
    res.end(body);
  } catch {
    res.writeHead(404);
    res.end("Not found");
  }
}

async function route(req, res) {
  const url = new URL(req.url, `http://${req.headers.host}`);

  if (req.method === "GET" && url.pathname === "/api/dashboard") {
    json(res, 200, await dashboardData());
    return;
  }

  if (req.method === "GET" && url.pathname === "/api/actions") {
    json(res, 200, { actions: await readActions() });
    return;
  }

  if (req.method === "GET" && url.pathname === "/api/status") {
    const actions = await readActions();
    json(res, 200, systemStatus(actions));
    return;
  }

  if (req.method === "POST" && url.pathname === "/api/actions") {
    const body = await requestBody(req);
    const action = body.action;
    if (!allowedActions.includes(action)) {
      json(res, 400, { error: `action must be one of ${allowedActions.join(", ")}` });
      return;
    }
    const actions = await readActions();
    const record = {
      id: `act-${Date.now()}`,
      action,
      status: "recorded",
      approvedBy: body.approvedBy || "dashboard-local",
      createdAt: new Date().toISOString(),
      dispatchPayload: dispatchPayload(action),
      command: `GitHub workflow dispatch prepared for ${action}; execute through Slack/API Gateway in live mode.`
    };
    actions.push(record);
    await writeActions(actions);
    json(res, 201, { record, dashboard: await dashboardData() });
    return;
  }

  if (req.method === "POST" && url.pathname === "/api/infra/apply-plan") {
    json(res, 200, { mode: "plan-only", commands: commandPlan("apply") });
    return;
  }

  if (req.method === "POST" && url.pathname === "/api/infra/destroy-plan") {
    json(res, 200, { mode: "plan-only", commands: commandPlan("destroy") });
    return;
  }

  await serveStatic(req, res, url.pathname);
}

createServer((req, res) => {
  route(req, res).catch((error) => json(res, 500, { error: error.message }));
}).listen(port, "0.0.0.0", () => {
  console.log(`CD Quality Gate dashboard backend: http://localhost:${port}`);
});
