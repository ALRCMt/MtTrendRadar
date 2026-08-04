
# MtTrendRadar

基于 [TrendRadar](https://github.com/sansan0/TrendRadar) v6.10.0 的修改版，自己加了点功能：AI 筛选增强、RSS 优化、MCP 安全加固

和官方版的差异在[文末](#与官方-trendradar-的差异)  
官方文档：<https://trendradar.sandev.cc/zh/docs/quick-start/>

## 快速开始

部署方式与官方一致（详见 [TrendRadar 快速开始](https://github.com/sansan0/TrendRadar#-快速开始)），以下仅标注本版的差异点。

### 方案一：Docker 部署（推荐）

两个镜像：`wantcat/trendradar`（新闻推送，必选）+ `wantcat/trendradar-mcp`（AI 分析，可选）。

```bash
git clone https://github.com/ALRCMt/MtTrendRadar.git
cd MtTrendRadar
docker compose -f docker/docker-compose.yml up -d
```

配置分工：

| 内容 | 位置 |
| --- | --- |
| 功能开关 | `config/config.yaml` |
| 关注内容 | `config/frequency_words.txt` |
| 密钥（webhook / API Key / S3） | `docker/.env` |

环境变量优先级高于 `config.yaml`。

注意点：

- `docker-compose.yml` 已内置 `MCP_HTTP_TOKEN` 环境变量，在 `docker/.env` 写 `MCP_HTTP_TOKEN=你的token` 即可开启 MCP 认证
- `MCP_HOST` 默认 `127.0.0.1`（仅本机）；对外开放需改为 `0.0.0.0` 并**必须**配置 `MCP_HTTP_TOKEN`
- 其余环境变量与官方一致，`docker/.env` 模板已包含

### 方案二：GitHub Actions 部署

Use this template 建仓库 → `Settings` > `Secrets and variables` > `Actions` 配置通知渠道（`WEWORK_WEBHOOK_URL`、`FEISHU_WEBHOOK_URL` 等，名称需与官方一致）→ 定时自动运行。数据走远程云存储，需配置 `S3_*` 系列 Secret。

注意点：

- 定时为北京时间 6:00 / 10:30 / 19:30（官方为每小时第 33 分钟），改时间编辑 `.github/workflows/crawler.yml` 的 cron

> GitHub Actions 有排队延迟：白天约晚 2h，晚上约晚 1h

### 方案三：本地部署（uv）

```bash
git clone https://github.com/ALRCMt/MtTrendRadar.git
cd MtTrendRadar
uv sync          # uv 自动管理 Python 依赖
uv run python -m trendradar
```

Windows 可双击 `setup-windows.bat`，macOS 用 `bash setup-mac.sh`。

注意点：

- MCP HTTP 模式默认只监听 `127.0.0.1`，远程访问需加 `--host 0.0.0.0 --token`（见下节）
- 本版新增的 AI 配置（`thinking_mode`、`reference_history_days` 等）见文末「配置」

## MCP HTTP 认证

原版 MCP HTTP 默认监听 `0.0.0.0` 且没有认证，局域网内谁都能调。这里改成默认只监听 `127.0.0.1`，并加了 Bearer Token 认证

### 配置 Token

命令行传 `--token`：

```bash
openssl rand -hex 32   # 生成 token
uv run python -m mcp_server.server --transport http --host 0.0.0.0 --port 3333 --token <生成的token>
```

或环境变量 `MCP_HTTP_TOKEN`：

```bash
# PowerShell
$env:MCP_HTTP_TOKEN = "token"
uv run python -m mcp_server.server --transport http

# Linux / macOS / Docker
export MCP_HTTP_TOKEN="token"
uv run python -m mcp_server.server --transport http
```

优先级：`--token` 参数 > `MCP_HTTP_TOKEN` 环境变量 > 不认证

Docker 部署在 `docker/.env` 里加一行：

```ini
MCP_HTTP_TOKEN=你的token
```

### 客户端调用

开启认证后，请求头要带 `Authorization`，否则返回 401：

```bash
curl -X POST http://127.0.0.1:3333/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer 你的token" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize",...}'
```

MCP 客户端（Cursor、Claude Desktop、Cherry Studio 等）把 `Authorization: Bearer <token>` 填进 HTTP Headers 就行

只在本地用（默认 `127.0.0.1`）可以不配；只要 `--host 0.0.0.0` 对网络开放，就必须配

## 与官方 TrendRadar 的差异

对比 v6.10.0 的改动：

### MCP Server

- 默认监听从 `0.0.0.0` 改为 `127.0.0.1`，仅本机可访问
- 新增 Bearer Token 认证：`--token` 参数或 `MCP_HTTP_TOKEN` 环境变量，未携带正确 Token 的请求返回 401

### AI 分析

- **全量分析**：新增 `analysis_min_score`，分数低于推送阈值 `min_score` 但 ≥ `analysis_min_score` 的条目仅进入 AI 深度分析、不推送；深度分析使用全天全量数据，不受每标签 `MAX_NEWS_PER_KEYWORD`（20 条）展示截断影响
- **历史参考**：新增 `reference_history_days`（默认 3，0=关闭）。每次深度分析结果存入数据库 `ai/` 库，下次分析自动参考最近 N 天（含当天多次）的历史结果，延续研判逻辑并对比变化；输入 token 增加约 2~4K/天
- **thinking_mode**：`ai.thinking_mode` 支持 DeepSeek V4 思考模式（快速 / 推理）
- **容错增强**：AI 筛选 / 翻译空响应自动重试；日韩文自动识别并翻译，纯中文跳过

### RSS / 爬虫

- 抓取重试次数提升至 4 次并随机退避
- 每个 feed 可单独限制条数（`rss.feeds[].max_items`）
- 标题模糊去重：包含关系或相似度 > 0.85 只保留最长一条
- 修复：RSS 新增条目不再被跳过翻译

### HTML 报告

- RSS 区新增按关键词分组的 Tab 栏（含「全部」按钮）
- 独立展示区显示逻辑调整

### 调度

- 定时从官方每小时改为北京时间 6:00 / 10:30 / 19:30
- `workflow_dispatch` 手动触发时注入 `SCHEDULE_PRESET=always_on`

> GitHub Actions 有排队延迟：白天约晚 2h，晚上约晚 1h

其余代码文件与官方 v6.10.0 一致。

## 配置

新增配置都在 `config/config.yaml`（`thinking_mode` 在 `ai` 段，其余在各功能段）：

```yaml
ai:
  thinking_mode: false          # DeepSeek V4 思考模式：false=快速 / true=推理 / 留空=不发送

ai_analysis:
  reference_history_days: 3     # AI 分析历史参考窗口：0=关闭 / N=参考最近 N 天（含当天多次）

ai_filter:
  max_empty_retries: 2          # AI 筛选空响应重试次数（0=不重试）

ai_translation:
  max_empty_retries: 2          # 翻译空响应/不完整响应重试次数（0=不重试）
  min_parse_ratio: 0.5          # 解析条数低于该比例视为不完整并重试

rss:
  feeds:
    - id: "example"
      max_items: 12             # 该 feed 最多保留条数（0=不限制）
```

## License

MIT，与上游一致