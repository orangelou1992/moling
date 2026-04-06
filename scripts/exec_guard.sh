#!/bin/bash
# exec_guard.sh - Exec 保护 + Tool Pipeline 集成
#
# 双重职责：
# 1. 防止长时运行被 SIGKILL（OpenClaw对exec有60s限制）
# 2. 将exec通过Tool Pipeline执行（L1权限检查 + L4结果提取）
#
# 用法: exec_guard.sh <timeout> <command> [args...]
#   timeout: 最大秒数 (默认 50s，留10s buffer)
#   command: 要执行的命令
#
# 环境变量:
#   USE_PIPELINE=1  - 强制通过tool_pipeline执行（默认1）
#   SKIP_PIPELINE=1 - 跳过pipeline，直接执行
#   PIPELINE_LOG=   - 自定义pipeline日志路径

set -e

MAX_TIMEOUT="${1:-50}"
shift
CMD="$*"

if [ -z "$CMD" ]; then
    echo "Usage: exec_guard.sh <timeout> <command> [args...]" >&2
    exit 1
fi

PIPELINE_DIR="$HOME/.openclaw/workspace/scripts"
PIPELINE_LOG="${PIPELINE_LOG:-/tmp/tool_pipeline_exec_$$.log}"
USE_PIPELINE="${USE_PIPELINE:-1}"

# 如果不是exec命令，直接执行
if [ "$USE_PIPELINE" != "1" ]; then
    timeout "$MAX_TIMEOUT" bash -c "$CMD"
    exit $?
fi

# 通过Tool Pipeline执行
# L1权限检查 + L2 context检查 + L3执行 + L4 auto_extract + L5日志
export TOOL_PIPELINE_LOG="$PIPELINE_LOG"
export TIMEOUT="$MAX_TIMEOUT"

bash "$PIPELINE_DIR/tool_pipeline.sh" exec "$MAX_TIMEOUT" "$CMD"
exit $?
