#!/bin/bash
# context_monitor.sh - Claude Code风格的5阈值Context管理
# 基于Claude Code的Autocompact/Error/Warning/CircuitBreaker/HardBlocking

SESSION_FILE="${HOME}/.openclaw/workspace/SESSION-STATE.md"
MEMORY_FILE="${HOME}/.openclaw/workspace/MEMORY.md"
COMPACT_SCRIPT="${HOME}/.openclaw/workspace/scripts/compact_context.sh"

# 5个阈值常数（token估算：中文≈2token/字，英文≈1.25token/词）
AUTOCOMPACT_MARGIN=13000
WARNING_THRESHOLD=15000
ERROR_THRESHOLD=17000
HARD_BLOCKING=27000
CIRCUIT_BREAKER=3

# 获取当前使用量估算
get_usage() {
    if [ -f "$SESSION_FILE" ]; then
        # 估算：读取文件行数×2（中文环境）
        local lines=$(wc -c < "$SESSION_FILE")
        local tokens=$((lines / 2))
        echo $tokens
    else
        echo 0
    fi
}

# 获取circuit breaker计数
get_circuit_count() {
    python3 -c "
import json, os
f = os.path.expanduser('$HOME/.openclaw/.circuit_breaker')
if os.path.exists(f):
    with open(f) as fp:
        d = json.load(fp)
    print(d.get('count', 0))
else:
    print(0)
" 2>/dev/null
}

# 增加circuit breaker计数
increment_circuit() {
    python3 << EOF
import json, os
f = os.path.expanduser('$HOME/.openclaw/.circuit_breaker')
d = {'count': 0}
if os.path.exists(f):
    with open(f) as fp:
        d = json.load(fp)
d['count'] = d.get('count', 0) + 1
with open(f, 'w') as fp:
    json.dump(d, fp, indent=2)
print(f"Circuit count: {d['count']}")
EOF
}

# 重置circuit breaker
reset_circuit() {
    python3 << EOF
import json, os
f = os.path.expanduser('$HOME/.openclaw/.circuit_breaker')
d = {'count': 0, 'reset_at': '$(date -u +%Y-%m-%dT%H:%M:%SZ)'}
with open(f, 'w') as fp:
    json.dump(d, fp, indent=2)
print("Circuit breaker reset")
EOF
}

# 执行compact
do_compact() {
    echo "⚡ 触发Context压缩..."
    if [ -f "$COMPACT_SCRIPT" ]; then
        bash "$COMPACT_SCRIPT" "$SESSION_FILE" 60
    else
        # 手动compact：保留最后100行 + 摘要
        TMP="/tmp/compact_$(date +%s).txt"
        {
            echo "# Context压缩摘要"
            echo "_压缩时间: $(date '+%Y-%m-%d %H:%M')_"
            echo ""
            tail -100 "$SESSION_FILE"
        } > "$TMP"
        mv "$TMP" "$SESSION_FILE"
        echo "✓ 压缩完成"
    fi
    reset_circuit
}

# 主检查逻辑
check() {
    local usage=$(get_usage)
    local circuit=$(get_circuit_count)
    
    echo "=== Context Monitor ==="
    echo "使用量: ~${usage} tokens"
    echo "Autocompact阈值: ${AUTOCOMPACT_MARGIN}"
    echo "Warning阈值: ${WARNING_THRESHOLD}"
    echo "Error阈值: ${ERROR_THRESHOLD}"
    echo "Circuit breaker: ${circuit}/${CIRCUIT_BREAKER}"
    
    # 检查circuit breaker
    if [ "$circuit" -ge "$CIRCUIT_BREAKER" ]; then
        echo "🔴 CIRCUIT BREAKER: 连续失败次数达到上限，停止尝试"
        echo "需要手动干预"
        return 2
    fi
    
    # 检查是否超过hard blocking
    if [ "$usage" -ge "$HARD_BLOCKING" ]; then
        echo "🔴 HARD BLOCKING: Context已满，Session冻结"
        increment_circuit
        return 3
    fi
    
    # 检查是否需要compact
    if [ "$usage" -ge "$ERROR_THRESHOLD" ]; then
        echo "🟡 ERROR THRESHOLD: 需要立即压缩"
        do_compact
        return 1
    fi
    
    if [ "$usage" -ge "$WARNING_THRESHOLD" ]; then
        echo "🟡 WARNING: Context接近上限，考虑压缩"
        return 1
    fi
    
    if [ "$usage" -ge "$AUTOCOMPACT_MARGIN" ]; then
        echo "🟢 AUTOCOMPACT: 触发自动压缩"
        do_compact
        return 0
    fi
    
    echo "🟢 OK: Context使用正常"
    return 0
}

case "$1" in
    check) check ;;
    compact) do_compact ;;
    reset) reset_circuit ;;
    usage) get_usage ;;
    *) 
        echo "Usage: context_monitor.sh {check|compact|reset|usage}"
        check
        ;;
esac
