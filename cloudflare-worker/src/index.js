/**
 * TrendRadar 定时触发 Worker
 *
 * 定时调用 GitHub API 触发 workflow_dispatch：
 *   POST /repos/{owner}/{repo}/actions/workflows/{workflow}/dispatches
 *
 * 需要 secret: GITHUB_TOKEN
 *   - Classic PAT：勾选 workflow 权限
 *   - Fine-grained PAT：Actions 选 Read and write，仅授权本仓库
 *
 * 手动测试：浏览器或 curl 访问  GET /trigger  立即触发一次
 */

async function dispatch(env, cron = null) {
  const url = `https://api.github.com/repos/${env.GITHUB_OWNER}/${env.GITHUB_REPO}/actions/workflows/${env.GITHUB_WORKFLOW}/dispatches`;

  const body = { ref: env.GITHUB_REF || "master" };
  if (env.GITHUB_PRESET) {
    body.inputs = { preset: env.GITHUB_PRESET };
  }

  const resp = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.GITHUB_TOKEN}`,
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
      "User-Agent": "trendradar-trigger",
      "Content-Type": "application/json",
    },
    body: JSON.stringify(body),
  });

  if (!resp.ok) {
    const text = await resp.text();
    console.error(`GitHub dispatch failed: ${resp.status} ${text}`);
    return { ok: false, status: resp.status, detail: text };
  }

  console.log(`Dispatched ${env.GITHUB_WORKFLOW}${cron ? ` @ cron ${cron}` : ""}`);
  return { ok: true, status: 204 };
}

export default {
  async scheduled(event, env, ctx) {
    ctx.waitUntil(dispatch(env, event.cron));
  },

  async fetch(request, env) {
    const { pathname } = new URL(request.url);

    if (pathname === "/trigger") {
      const result = await dispatch(env);
      return new Response(
        result.ok
          ? "OK: dispatched"
          : `Failed: ${result.status}\n${result.detail || ""}`,
        {
          status: result.ok ? 200 : 500,
          headers: { "Content-Type": "text/plain; charset=utf-8" },
        }
      );
    }

    return new Response("trendradar-trigger: GET /trigger 立即触发一次", {
      status: 200,
      headers: { "Content-Type": "text/plain; charset=utf-8" },
    });
  },
};
