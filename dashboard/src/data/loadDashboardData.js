import { sampleDashboard } from "./sample-dashboard.js";

const LIVE_DATA_PATH = "./dashboard-data.json";

export async function loadDashboardData() {
  const params = new URLSearchParams(window.location.search);
  const mode = params.get("mode") || "demo";

  if (mode !== "live") {
    return { data: sampleDashboard, source: "demo fixture" };
  }

  try {
    const response = await fetch(LIVE_DATA_PATH, { cache: "no-store" });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const data = await response.json();
    return { data, source: LIVE_DATA_PATH };
  } catch (error) {
    return {
      data: {
        ...sampleDashboard,
        mode: "demo-fallback",
        generatedAt: new Date().toISOString(),
        liveError: `Live data unavailable: ${error.message}`
      },
      source: "demo fallback"
    };
  }
}
