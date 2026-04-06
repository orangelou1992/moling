#!/bin/bash
# exec_guard.sh - Exec 保护机制
# 防止长时运行被 SIGKILL，核心问题：OpenClaw 对 exec 有 60s SIGKILL 限制
# 解决：短时分片 + 子进程隔离 + 进度checkpoint

# 用法: exec_guard.sh <timeout> <command> [args...]
# timeout: 最大秒数 (默认 55s，留 5s buffer)
# 返回: command 退出码，或 137 (SIGKILL) 或 143 (SIGTERM)

MAX_TIMEOUT="${1:-55}"; shift
CMD="$*"

if [ -z "$CMD" ]; then
    echo "Usage: exec_guard.sh <timeout> <command> [args...]" >&2
    exit 1
fi

# 进度checkpoint文件（防止同命令重复运行）
CHECKPOINT="/tmp/exec_guard_$(echo "$CMD" | md5sum | cut -c1-8).chk"
PID_FILE="/tmp/exec_guard_$(echo "$CMD" | md5sum | cut -c1-8).pid"

# 如果checkpoint存在且进程还在跑，跳过
if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
        echo "WARN: same command already running (PID $OLD_PID), skipping" >&2
        exit 1
    fi
    rm -f "$CHECKPOINT" "$PID_FILE"
fi

# 启动子进程，记录 PID
(
    exec timeout --signal=KILL "$MAX_TIMEOUT" bash -c "$CMD"
) &
CHILD_PID=$!
echo $CHILD_PID > "$PID_FILE"

# 等待，带超时保护
wait $CHILD_PID 2>/dev/null
EXIT_CODE=$?

# 清理
rm -f "$PID_FILE"

if [ $EXIT_CODE -eq 137 ]; then
    echo "WARN: exec_guard SIGKILL (timeout=${MAX_TIMEOUT}s, cmd truncated)" >&2
elif [ $EXIT_CODE -eq 143 ]; then
    echo "WARN: exec_guard SIGTERM (timeout=${MAX_TIMEOUT}s)" >&2
fi

exit $EXIT_CODE
