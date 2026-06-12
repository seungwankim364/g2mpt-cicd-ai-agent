import { loadDashboardData } from "./data/loadDashboardData.js";

const STATUS_LABELS = {
  complete: "Complete",
  failed: "Failed",
  waiting: "Waiting",
  pending: "Pending",
  warning: "Warning",
  available: "Available",
  destroyed: "Destroyed",
  preserved: "Preserved",
  blocked: "Blocked",
  critical: "Critical"
};

const statusClass = (status = "") => `status ${status.toLowerCase().replaceAll("_", "-")}`;
const pct = (value) => `${Math.round(value * 100)}%`;

function createElement(tag, className, content) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (content !== undefined) node.textContent = content;
  return node;
}

function renderStatus(status) {
  const span = createElement("span", statusClass(status), STATUS_LABELS[status] || status);
  span.setAttribute("aria-label", `Status ${STATUS_LABELS[status] || status}`);
  return span;
}

function metricTile(label, value, tone = "neutral") {
  const tile = createElement("div", `metric-tile ${tone}`);
  tile.append(createElement("span", "metric-label", label));
  tile.append(createElement("strong", "metric-value", value));
  return tile;
}

function formatTime(value) {
  if (!value) return "-";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleString(undefined, { month: "short", day: "2-digit", hour: "2-digit", minute: "2-digit" });
}

function sectionHeader(title, description) {
  const wrap = createElement("div", "section-header");
  wrap.append(createElement("h2", "", title));
  if (description) wrap.append(createElement("p", "", description));
  return wrap;
}

function renderHeader(data, source) {
  const header = createElement("header", "topbar");
  const titleGroup = createElement("div", "title-group");
  titleGroup.append(createElement("p", "eyebrow", "CD Quality Gate Control Center"));
  titleGroup.append(createElement("h1", "", `${data.deployment.service} / ${data.deployment.environment}`));
  titleGroup.append(createElement("p", "subtitle", `${data.deployment.repository} · ${data.deployment.argocdApp} · ${data.deployment.namespace}`));

  const actions = createElement("div", "top-actions");
  actions.append(renderStatus(data.deployment.status));
  actions.append(createElement("span", "source-pill", source));
  actions.append(createElement("span", "source-pill", `Updated ${formatTime(data.deployment.lastUpdatedAt)}`));

  header.append(titleGroup, actions);
  return header;
}

function renderOverview(data) {
  const section = createElement("section", "overview-grid");
  section.append(metricTile("Image tag", data.deployment.imageTag, "info"));
  section.append(metricTile("Rollback tag", data.deployment.rollbackImageTag || "not set", "warn"));
  section.append(metricTile("Health window", `${data.healthWindow.durationSeconds / 60} min`, data.healthWindow.result === "failed" ? "danger" : "ok"));
  section.append(metricTile("AI confidence", pct(data.analysis.confidence), data.analysis.confidence > 0.75 ? "ok" : "warn"));
  return section;
}

function renderTimeline(data) {
  const section = createElement("section", "panel wide");
  section.append(sectionHeader("Deployment Timeline", "Where the current deployment is in the CD chain"));

  const list = createElement("ol", "timeline");
  data.timeline.forEach((item) => {
    const row = createElement("li", `timeline-item ${item.status}`);
    const marker = createElement("span", "timeline-marker");
    const content = createElement("div", "timeline-content");
    const head = createElement("div", "timeline-head");
    head.append(createElement("strong", "", item.label), renderStatus(item.status));
    content.append(head);
    content.append(createElement("p", "", item.detail));
    const meta = createElement("div", "timeline-meta");
    meta.append(createElement("span", "", item.owner), createElement("span", "", item.at));
    content.append(meta);
    row.append(marker, content);
    list.append(row);
  });

  section.append(list);
  return section;
}

function gauge(label, value, max, unit) {
  const ratio = Math.min(value / max, 1);
  const wrap = createElement("div", "gauge");
  const top = createElement("div", "gauge-top");
  top.append(createElement("span", "", label), createElement("strong", "", unit ? `${value}${unit}` : pct(value)));
  const bar = createElement("div", "bar");
  const fill = createElement("span", ratio > 0.8 ? "fill danger" : ratio > 0.55 ? "fill warn" : "fill ok");
  fill.style.width = `${Math.max(ratio * 100, 4)}%`;
  bar.append(fill);
  wrap.append(top, bar);
  return wrap;
}

function renderHealth(data) {
  const section = createElement("section", "panel");
  section.append(sectionHeader("Quality Gate Health", "5 minute Prometheus alert and metric window"));

  const sampleGrid = createElement("div", "sample-grid");
  data.healthWindow.samples.forEach((sample) => {
    const item = createElement("div", `sample ${sample.result}`);
    item.append(createElement("span", "", sample.at));
    item.append(createElement("strong", "", `${sample.alerts} alerts`));
    item.append(createElement("small", "", `${sample.latencyMs}ms p95`));
    sampleGrid.append(item);
  });
  section.append(sampleGrid);

  const gauges = createElement("div", "gauge-grid");
  gauges.append(gauge("5xx error", data.healthWindow.metrics.errorRate, 10, "%"));
  gauges.append(gauge("p95 latency", data.healthWindow.metrics.p95LatencySeconds, 3, "s"));
  gauges.append(gauge("DB pool", data.healthWindow.metrics.dbPoolUsageRatio, 1, ""));
  gauges.append(gauge("JVM heap", data.healthWindow.metrics.jvmHeapUsageRatio, 1, ""));
  section.append(gauges);
  return section;
}

function renderAlerts(data) {
  const section = createElement("section", "panel wide");
  section.append(sectionHeader("Alert Coverage", "Backend, EKS, Redis, SQS, GPU, and Bedrock-ready checks"));

  const grid = createElement("div", "alert-grid");
  data.alertGroups.forEach((group) => {
    const item = createElement("article", `alert-group ${group.severity}`);
    const head = createElement("div", "alert-group-head");
    head.append(createElement("h3", "", group.name), createElement("strong", "", `${group.count}`));
    item.append(head);
    item.append(renderStatus(group.severity));
    const dashboards = createElement("div", "dashboard-tags");
    group.dashboards.forEach((dashboard) => dashboards.append(createElement("span", "", dashboard)));
    item.append(dashboards);

    const list = createElement("ul", "compact-list");
    group.alerts.forEach((alert) => {
      const li = createElement("li", "");
      li.append(createElement("strong", "", alert.name));
      li.append(createElement("span", "", alert.summary));
      li.append(createElement("em", "", alert.value));
      list.append(li);
    });
    item.append(list);
    grid.append(item);
  });
  section.append(grid);
  return section;
}

function renderAnalysis(data) {
  const section = createElement("section", "panel");
  section.append(sectionHeader("AI Incident Analysis", `${data.analysis.engine} · ${data.analysis.model}`));
  section.append(metricTile("Recommended action", data.analysis.recommendedAction, "danger"));
  section.append(createElement("p", "analysis-summary", data.analysis.summary));

  const causes = createElement("div", "cause-list");
  data.analysis.causeCandidates.forEach((cause) => {
    const row = createElement("div", "cause");
    row.append(createElement("strong", "", cause.title));
    row.append(gauge("confidence", cause.score, 1, ""));
    row.append(createElement("p", "", cause.evidence));
    causes.append(row);
  });
  section.append(causes);

  const steps = createElement("ol", "next-steps");
  data.analysis.nextSteps.forEach((step) => steps.append(createElement("li", "", step)));
  section.append(steps);
  return section;
}

function renderApprovals(data) {
  const section = createElement("section", "panel");
  section.append(sectionHeader("Approval & Action", "Slack approval to GitHub workflow dispatch"));
  const table = createElement("div", "table");
  const header = createElement("div", "table-row table-head");
  ["Action", "Status", "Target", "Workflow"].forEach((text) => header.append(createElement("span", "", text)));
  table.append(header);

  data.approvals.forEach((item) => {
    const row = createElement("div", "table-row");
    row.append(createElement("strong", "", item.action));
    const statusCell = createElement("span", "");
    statusCell.append(renderStatus(item.status));
    row.append(statusCell);
    row.append(createElement("span", "", item.target));
    row.append(createElement("span", "", item.workflow));
    table.append(row);
  });
  section.append(table);
  return section;
}

function renderInfra(data) {
  const section = createElement("section", "panel");
  section.append(sectionHeader("Infra & Cost", "Terraform stack state and destroy readiness"));
  const meta = createElement("div", "infra-meta");
  meta.append(metricTile("Terraform state", data.infra.terraformState, data.infra.terraformState === "destroyed" ? "ok" : "warn"));
  meta.append(metricTile("Last destroy", formatTime(data.infra.lastDestroy), "neutral"));
  section.append(meta);

  const resources = createElement("div", "resource-list");
  data.infra.resources.forEach((resource) => {
    const row = createElement("div", "resource-row");
    row.append(createElement("span", "", resource.name));
    row.append(createElement("strong", "", `${resource.count}`));
    row.append(renderStatus(resource.status));
    resources.append(row);
  });
  section.append(resources);

  const checklist = createElement("div", "checklist");
  data.infra.checklist.forEach((item) => {
    const row = createElement("div", `check ${item.status}`);
    row.append(createElement("span", "check-dot"));
    row.append(createElement("span", "", item.label));
    row.append(renderStatus(item.status));
    checklist.append(row);
  });
  section.append(checklist);
  return section;
}

function renderLinks(data) {
  const section = createElement("section", "link-strip");
  const links = [
    ["Grafana", data.links.grafana],
    ["Prometheus", data.links.prometheus],
    ["Argo CD", data.links.argocd],
    ["GitHub Actions", data.links.githubRun],
    ["Slack", data.links.slackChannel]
  ];
  links.forEach(([label, href]) => {
    const link = document.createElement(href.startsWith("http") ? "a" : "span");
    link.className = "quick-link";
    link.textContent = label;
    if (link.tagName === "A") {
      link.href = href;
      link.target = "_blank";
      link.rel = "noreferrer";
    }
    section.append(link);
  });
  return section;
}

function render(data, source) {
  const app = document.querySelector("#app");
  app.innerHTML = "";
  app.append(renderHeader(data, source));
  if (data.liveError) app.append(createElement("div", "notice", data.liveError));
  app.append(renderOverview(data));

  const layout = createElement("main", "dashboard-layout");
  layout.append(renderTimeline(data));
  layout.append(renderHealth(data));
  layout.append(renderAlerts(data));
  layout.append(renderAnalysis(data));
  layout.append(renderApprovals(data));
  layout.append(renderInfra(data));
  app.append(layout);
  app.append(renderLinks(data));
}

loadDashboardData().then(({ data, source }) => render(data, source));
