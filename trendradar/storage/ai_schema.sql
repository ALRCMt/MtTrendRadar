-- ═══════════════════════════════════════════════════════════════
-- AI 深度分析历史表结构
-- 用途：保存每次 AI 深度分析的结果，供后续分析参考历史趋势
-- 组织方式：每天一个数据库文件（ai/YYYY-MM-DD.db），
--           同一天多次分析通过 INSERT 多行合并，按 created_at 区分
-- ═══════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS ai_analyses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    analysis_date TEXT NOT NULL,          -- 分析日期 (YYYY-MM-DD)
    created_at TEXT NOT NULL,             -- 创建时间（含时分秒，用于同天多次分析排序）
    report_mode TEXT DEFAULT '',          -- 推送报告模式 (daily/current/incremental)
    report_type TEXT DEFAULT '',          -- 报告类型描述
    ai_mode TEXT DEFAULT '',              -- AI 分析实际使用的模式
    core_trends TEXT DEFAULT '',          -- 核心热点与舆情态势
    sentiment_controversy TEXT DEFAULT '',-- 舆论风向与争议
    signals TEXT DEFAULT '',              -- 异动与弱信号
    rss_insights TEXT DEFAULT '',         -- RSS 深度洞察
    outlook_strategy TEXT DEFAULT '',     -- 研判与策略建议
    standalone_summaries TEXT DEFAULT '', -- 独立展示区概括 (JSON 字符串)
    total_news INTEGER DEFAULT 0,         -- 新闻总数（热榜+RSS）
    hotlist_count INTEGER DEFAULT 0,      -- 热榜新闻数
    rss_count INTEGER DEFAULT 0,          -- RSS 新闻数
    analyzed_news INTEGER DEFAULT 0,      -- 实际分析新闻数
    max_news_limit INTEGER DEFAULT 0      -- 分析上限配置值
);

CREATE INDEX IF NOT EXISTS idx_ai_analyses_date ON ai_analyses (analysis_date, created_at);
