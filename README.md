
# MtTrendRadar

基于 [TrendRadar](https://github.com/sansan0/TrendRadar) v6.10.0 的修改版，自己加了点功能：AI 筛选增强、RSS 优化、MCP 安全加固

和官方版的差异在[文末](#与官方-trendradar-的差异)  
官方文档：<https://trendradar.sandev.cc/zh/docs/quick-start/>

## 快速开始

部署方式和原版一样，官方文档见 [TrendRadar 快速开始](https://github.com/sansan0/TrendRadar#-快速开始)，下面标了不同的注意点

### 方案一：Docker 部署（推荐）

原版说明：两个镜像，`wantcat/trendradar`（新闻推送，必选）+ `wantcat/trendradar-mcp`（AI 分析，可选）。克隆项目后改 `config/` 和 `docker/.env`，然后：

```bash
git clone https://github.com/ALRCMt/MtTrendRadar.git
cd MtTrendRadar
docker compose -f docker/docker-compose.yml up -d
```

配置分工：功能开关改 `config/config.yaml`，关注内容改 `config/frequency_words.txt`，密钥（webhook、API Key、S3）改 `docker/.env`，环境变量 > config.yaml

注意点：

- `docker-compose.yml` 已加了 `MCP_HTTP_TOKEN` 环境变量，部署 MCP 时在 `docker/.env` 里写 `MCP_HTTP_TOKEN=你的token` 就开启认证
- `MCP_HOST` 默认 `127.0.0.1`（只本机可访问）；要外部访问改成 `0.0.0.0`，**必须**同时配 `MCP_HTTP_TOKEN`
- 其余环境变量和官方一样，`docker/.env` 模板里都有，照填即可

### 方案二：GitHub Actions 部署

原版说明：Use this template 建仓库 → 在 `Settings` > `Secrets and variables` > `Actions` 配通知渠道（`WEWORK_WEBHOOK_URL`、`FEISHU_WEBHOOK_URL` 等，Name 必须和官方一致）→ Actions 定时自动跑。数据走远程云存储，需配 `S3_*` 系列 Secret 

注意点：

- 定时任务是北京时间 6:00 / 10:30 / 19:30（官方是每小时第 33 分钟），想改时间编辑 `.github/workflows/crawler.yml` 里的 cron

> 由于排队机制，Github Actions 自动执行有延迟，大概白天晚2h，晚上晚1h

### 方案三：本地部署（uv）

原版说明：装 uv（自动管理 Python）→ clone → `uv sync` → 编辑 `config/config.yaml` → 运行

```bash
git clone https://github.com/ALRCMt/MtTrendRadar.git
cd MtTrendRadar
uv sync
uv run python -m trendradar
```

Windows 可双击 `setup-windows.bat`，macOS 用 `bash setup-mac.sh`

注意点：

- MCP HTTP 模式默认只监听 `127.0.0.1`，远程访问要加 `--host 0.0.0.0 --token`（见下节）
- 新增的 AI 配置（`thinking_mode`、`min_score` 等）见文末「配置」

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

对比 v6.10.0 的差异

### MCP Server 安全加固

- **mcp_server/server.p**y：  
  默认监听 `0.0.0.0` → `127.0.0.1`；  
  新增 `--token` 参数、`MCP_HTTP_TOKEN` 环境变量；加了纯 ASGI 的 `BearerAuthMiddleware`，请求头不对返回 401；启动时打印认证状态

- **start-http.bat** / **start-http.sh**：  
  默认 `--host 127.0.0.1 --port 3333`

- **docker/Dockerfile.mcp**：  
  补充注释，说明容器内绑定 0.0.0.0 是必要的，外部范围由 compose 的 `MCP_HOST` 控制

- d**ocker/docker-compose.yml** / **docker-compose-build.yml**：  
  MCP 服务环境变量加 `MCP_HTTP_TOKEN=${MCP_HTTP_TOKEN:-}`

- **docker/.env**：  
  加 `MCP_HTTP_TOKEN` 注释示例

### AI 分析

- **最低分阈值 + AI 全量分析**：  
  `filter_pipeline.py` 的 `convert_to_report_data()` 加 `analysis_min_score` 和 `max_news` 参数。分数低于 `min_score` 但 ≥ `analysis_min_score` 的条目标记 `is_analysis_only=True`，只供 AI 分析参考，不推送。AI 深度分析传 `max_news=0` 生成全量数据——覆盖全天所有 ≥ `analysis_min_score` 的结果，不受每标签 `MAX_NEWS_PER_KEYWORD`（默认 20）展示截断影响；  
  推送/HTML 仍用默认截断版。`context.py` 和 `__main__.py` 配套改动（新增 `_strip_analysis_only()` 剔除弱信号条目、拆分推送/AI 分析两份数据流）

- **DeepSeek V4 thinking**：  
  `ai/client.py` 支持 `thinking_mode`，用 `extra_body={"thinking": {"type": "enabled"/"disabled"}}` 控制，同时支持 `extra_params` 合并

- **空响应重试**：  
  `ai/filter.py` 的 `extract_tags()` / `update_tags()` 支持 `max_empty_retries` 重试（读配置 `ai_filter.max_empty_retries`，默认 2）；`ai/translator.py` 解析条数低于 `min_parse_ratio`（默认 0.5）视为不完整并重试

- **目标语言预判**：  
  `ai/translator.py` 加 `_is_already_target_language()`：日文假名/韩文谚文占比 ≥ 5% 判定为日韩文送去翻译（避免密集汉字的日文漏翻）；纯中文（CJK 占比 ≥ 60%）跳过翻译

- **RSS 配额**：  
  `ai/analyzer.py` 给 RSS 预留 `max(30, int(max_news * 0.2))` 的展示配额

- **AI 分析历史存储与参考**：  
  新增 `ai_analysis.reference_history_days` 配置（默认 3，0=关闭）。开启后每次 AI 深度分析会把本次结果（5 大板块 + 独立展示区概括 + 日期/模式标注）存入数据库 `ai/YYYY-MM-DD.db`（同一天多次分析独立存多行，随 news/rss 一起走下载-合并-上传流程）；下一次深度分析会读取最近 N 天（含当天）的历史分析作为提示词中的 `{history_reference}` 参考，要求 AI 延续此前研判逻辑并对比新变化  
  存储层：`storage/ai_schema.sql`（`ai_analyses` 表）+ `sqlite_mixin.py` 的 `_save_ai_analysis_impl` / `_get_recent_ai_analyses_impl`，`base.py`/`local.py`/`remote.py`/`manager.py` 全链路支持（remote 自动下载/上传 `ai/` 库）  
  注意：参考历史会增加深度分析输入 token，请按需设置

### RSS / 爬虫

- **crawler/rss/fetcher.py**：  
  最多重试 4 次，随机退避

- **crawler/fetcher.py**：  
  `max_retries` 2 → 4

- **filter_pipeline.py**：  
  按 feed 单独限制条数（配置里加 `max_items`）；  
  新增标题模糊去重 `_deduplicate_titles()`，包含关系或相似度 > 0.85 只保留最长的一条

- **notification/dispatcher.py**：  
  修了个 bug——RSS 新增条目（`rss_new_items`）原来会被 `display_regions.get("NEW_ITEMS", True)` 跳过翻译，导致 HTML 里出现未翻译内容，现在不会了

### HTML 报告

- **report/html.py**：  
  RSS 区加按关键词分组的 Tab 栏（含「全部」按钮，宽屏显示、竖屏隐藏）；  
  独立展示区 Tab 改为控制外层 wrapper 显隐；  
  RSS 新增区块由 `show_new_section`（`display.regions.new_items`）控制

### CI / 调度

- **.github/workflows/crawler.yml**：  
  定时改为北京时间 6:00 / 10:30 / 19:30（原版每小时第 33 分钟）；  
  `workflow_dispatch` 手动触发时注入 `SCHEDULE_PRESET=always_on`

> 由于排队机制，Github Actions 自动执行有延迟，大概白天晚2h，晚上晚1h

### 文件结构

- `config/config.yaml` 新增：  
`ai.thinking_mode`、`ai_filter.max_empty_retries`、`ai_translation.max_empty_retries` / `min_parse_ratio`、RSS feed 的 `max_items`（官方 `min_score` 默认 0.7，这里改成了 0.65）

其余代码文件和官方 v6.10.0 一致

## 配置

新增配置都在 `config/config.yaml`（`thinking_mode` 在 `ai` 段，其余在各功能段）：

```yaml
ai:
  thinking_mode: false          # DeepSeek V4 思考模式：false=快速 / true=推理 / 留空=不发送

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

（`ai_filter.min_score` 官方本来就有，默认 0.7，这里只是把默认值改成 0.65）

## License

MIT，与上游一致