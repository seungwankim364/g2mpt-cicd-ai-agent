import { sampleDashboard } from "./sample-dashboard.js";

const LIVE_DATA_PATH = "./dashboard-data.json";
const API_DASHBOARD_PATH = "/api/dashboard";

export async function loadDashboardData() {
  const params = new URLSearchParams(window.location.search);
  const mode = params.get("mode") || "api";

  if (mode === "demo") {
    return { data: sampleDashboard, source: "demo fixture" };
  }

  if (mode !== "live") {
    try {
      const response = await fetch(API_DASHBOARD_PATH, { cache: "no-store" });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = await response.json();
      return { data, source: "local backend" };
    } catch (error) {
      return {
        data: {
          ...sampleDashboard,
          mode: "demo-fallback",
          generatedAt: new Date().toISOString(),
          liveError: `Dashboard backend unavailable: ${error.message}`
        },
        source: "demo fallback"
      };
    }
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
