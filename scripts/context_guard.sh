#!/bin/bash
# context_guard.sh - Context监控 + Autocompact触发
# 每5分钟由autonomous_loop调用
# 阈值：60%触发压缩，85%紧急快照+告警

WORKSPACE="$HOME/.openclaw/workspace"
THRESHOLD="${1:-60}"
URGENT="${2:-85}"

# 从心跳状态文件读取（OpenClaw每次heartbeat更新）
get_context_pct() {
    local state="$HOME/.openclaw/workspace/memory/heartbeat-state.json"
    if [ -f "$state" ]; then
        python3 -c "
import json, sys
try:
    with open('$state') as f:
        s = json.load(f)
    # 支持多种key格式
    for k in ['memory.usage_pct', 'usage_pct', 'context_pct', 'pct']:
        parts = k.split('.')
        v = s
        for p in parts:
            v = v.get(p, {})
        if isinstance(v, (int, float)):
            print(int(v))
            sys.exit(0)
except: pass
print(3)  # 默认低
"
    else
        echo 3
    fi
}

main() {
    local pct=$(get_context_pct)
    
    if [ "$pct" -ge "$URGENT" ]; then
        echo "[context_guard] 🚨 紧急: ${pct}% ≥ ${URGENT}%！紧急快照"
        bash "$WORKSPACE/scripts/session_checkpoint.sh" 2>/dev/null
        echo "[context_guard] 🚨 告警已记录，请Daniel注意"
    elif [ "$pct" -ge "$THRESHOLD" ]; then
        echo "[context_guard] ⚠️ ${pct}% ≥ ${THRESHOLD}%，触发autocompact"
        bash "$WORKSPACE/scripts/autocompact.sh" "$THRESHOLD" 2>/dev/null
    else
        echo "[context_guard] ✅ context ${pct}% < ${THRESHOLD}%，无需操作"
    fi
}

main
