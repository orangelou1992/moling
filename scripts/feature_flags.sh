#!/bin/bash
# feature_flags.sh - Tengu风格混淆Feature Flag系统
# 基于Claude Code泄露源码的87个Feature Flags设计

FEATURE_DB="${HOME}/.openclaw/feature_flags.json"

# Tengu混淆命名映射表
declare -A TENGU_FLAGS=(
    ["tengu_passport_quail"]="memory_extraction_gate"
    ["tengu_moth_copse"]="memory_extraction_enable"
    ["tengu_bramble_lintel"]="memory_extraction_freq"
    ["tengu_kairos"]="proactive_mode"
    ["tengu_amber_json_tools"]="json_tool_format"
    ["tengu_fennel_vole"]="context_compact_enable"
    ["tengu_larch_skua"]="permission_auto_mode"
    ["tengu_dunlin_slate"]="subagent_isolation"
    ["tengu_merlin_ink"]="terminal_ui_enable"
    ["tengu_oriole_fawn"]="streaming_response"
)

# 获取flag状态
get_flag() {
    local flag=$1
    if [ -f "$FEATURE_DB" ]; then
        local value=$(python3 -c "
import json
try:
    with open('$FEATURE_DB', 'r') as f:
        flags = json.load(f)
    flag = '$flag'
    if flag in flags:
        print(flags[flag])
    else:
        print('undefined')
except: print('undefined')
" 2>/dev/null)
        echo "$value"
    else
        echo "undefined"
    fi
}

# 设置flag
set_flag() {
    local flag=$1
    local value=$2
    python3 << EOF
import json, os
db = os.path.expanduser('$FEATURE_DB')
flags = {}
if os.path.exists(db):
    with open(db, 'r') as f:
        flags = json.load(f)
flags['$flag'] = '$value'
with open(db, 'w') as f:
    json.dump(flags, f, indent=2)
print(f"Set $flag = $value")
EOF
}

# 检查tengu flag
check_tengu() {
    local tengu=$1
    local real_name=${TENGU_FLAGS[$tengu]}
    if [ -z "$real_name" ]; then
        echo "unknown_flag"
        return
    fi
    get_flag "$real_name"
}

# 列出所有flags
list_flags() {
    echo "=== Feature Flags ==="
    for tengu in "${!TENGU_FLAGS[@]}"; do
        real="${TENGU_FLAGS[$tengu]}"
        status=$(get_flag "$real")
        echo "  $tengu → $real: $status"
    done
}

case "$1" in
    get) get_flag "$2" ;;
    set) set_flag "$2" "$3" ;;
    check) check_tengu "$2" ;;
    list) list_flags ;;
    *) echo "Usage: feature_flags.sh {get|set|check|list}" ;;
esac
