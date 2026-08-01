@echo off
chcp 65001 >nul

echo ============================================================
echo   TrendRadar MCP Server (HTTP 模式)
echo ============================================================
echo.

REM 检查虚拟环境
if not exist ".venv\Scripts\python.exe" (
    echo ❌ [错误] 虚拟环境未找到
    echo 请先运行 setup-windows.bat 或 setup-windows-en.bat 进行部署
    echo.
    pause
    exit /b 1
)

echo [模式] HTTP (本机模式，默认仅本机可访问)
echo [地址] http://localhost:3333/mcp
echo [提示] 按 Ctrl+C 停止服务
echo.
echo [安全] 如需远程访问，请修改下方命令：
echo        --host 0.0.0.0 --token 你的访问令牌
echo        并可通过环境变量 MCP_HTTP_TOKEN 设置令牌
echo.

uv run python -m mcp_server.server --transport http --host 127.0.0.1 --port 3333

pause
