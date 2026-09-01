# TrendRadar 定时触发 Worker

GitHub Actions 自带的 `schedule` cron 调度不稳定（排队延迟可达数小时，即使提前 2~3h 仍会晚点），
本 Worker 用 Cloudflare 的 Cron Trigger 准点调用 GitHub API 触发 `crawler.yml` 的 `workflow_dispatch`。

## 定时

| 北京时间 | UTC | cron |
| --- | --- | --- |
| 00:00 | 16:00 | `0 4,10,16,22 * * *` |
| 06:00 | 22:00 | ↑（同上一条） |
| 12:00 | 04:00 | ↑（同上一条） |
| 18:00 | 10:00 | ↑（同上一条） |

> 4 个时间点合并为 1 条 cron，免费计划 3 个 Trigger 额度只用了 1 个，还余 2 个。
>
> 推送行为由 `config/timeline.yaml` 的 `custom` 预设控制：周一~周六 18:00 触发 → 晚间汇总推送；周日 06:00 触发 → 早间推送；其余触发点仅静默采集。

## 部署

```bash
cd cloudflare-worker

# 1. 登录 Cloudflare
npx wrangler login

# 2. 创建 GitHub PAT（workflow 权限）并写入 Worker secret
#    Classic PAT：Settings → Developer settings → Tokens → 勾选 workflow
#    Fine-grained PAT：Actions 选 Read and write，仅授权 MtTrendRadar
npx wrangler secret put GITHUB_TOKEN

# 3. 发布
npx wrangler deploy
```

## 验证

```bash
# 本地起服务
npx wrangler dev

# 手动触发一次（浏览器访问 http://localhost:8787/trigger 或）
curl http://localhost:8787/trigger
```

## 配置说明

- `wrangler.toml` 里的 `[vars]`：仓库信息 + `GITHUB_PRESET=custom`（与 `config/config.yaml` 的 `schedule.preset` 保持一致）
- 触发时会带 `inputs: { preset: "custom" }`，因此**不会**像以前手动触发那样被强制 `always_on`，而是按你的自定义时间线运行
- 想改定时时间：编辑 `wrangler.toml` 的 `[triggers] crons`（全部为 UTC）

## 备用：恢复 GitHub 自带定时

如果不想用 Cloudflare Worker，恢复 `.github/workflows/crawler.yml` 里被注释的 `schedule:` 块即可
（注意 GitHub Actions 定时有排队延迟，需自行提前补偿）。
