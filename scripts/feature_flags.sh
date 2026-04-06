#!/bin/bash
# feature_flags.sh - Tengu风格混淆Feature Flag系统
# 基于Claude Code泄露源码的87个Feature Flags设计
#
# Claude Code原文：
# - tengu_前缀 + 随机词对 = 即使泄露也无法推断功能
# - 87个flags分布在4个tier
#
# 本实现：20个核心flag，覆盖OpenClaw的关键能力

FEATURE_DB="${HOME}/.openclaw/feature_flags.json"

# Tengu混淆命名映射表（20个核心flag）
declare -A TENGU_FLAGS=(
    # === Tier 1: Memory & Context ===
    ["tengu_passport_quail"]="memory_extraction_gate"
    ["tengu_moth_copse"]="memory_extraction_enable"
    ["tengu_bramble_lintel"]="memory_extraction_freq"
    ["tengu_wren_sleet"]="context_compact_threshold"
    
    # === Tier 2: Autonomy & Proactivity ===
    ["tengu_kairos"]="proactive_mode"
    ["tengu_iris_loach"]="autonomous_tick_interval"
    ["tengu_bramble_lark"]="agent_trigger_enable"
    ["tengu_finch_syrup"]="self_dream_enable"
    
    # === Tier 3: Tool & Security ===
    ["tengu_larch_skua"]="permission_auto_mode"
    ["tengu_dunlin_slate"]="subagent_isolation"
    ["tengu_amber_json_tools"]="json_tool_format"
    ["tengu_coral_ash"]="tool_validation_strict"
    ["tengu_slate_pika"]="exec_timeout_max"
    ["tengu_heron_dill"]="path_whitelist_strict"
    
    # === Tier 4: UI & Output ===
    ["tengu_merlin_ink"]="terminal_ui_enable"
    ["tengu_oriole_fawn"]="streaming_response"
    ["tengu_vireo_weld"]="magic_docs_auto_save"
    ["tengu_fennel_vole"]="compact_on_high_context"
    ["tengu_kestrel_tufa"]="team_memory_sync"
    ["tengu_tern_bread"]="heartbeat_verbose"
)

# 获取flag状态
get_flag() {
    local flag="$1"
    if [ -f "$FEATURE_DB" ]; then
        python3 -c "
import json
try:
    with open('$FEATURE_DB', 'r') as f:
        flags = json.load(f)
    print(flags.get('$flag', 'undefined'))
except: print('undefined')
" 2>/dev/null
    else
        echo "undefined"
    fi
}

# 设置flag
set_flag() {
    local flag="$1"
    local value="$2"
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

# 检查tengu flag（混淆名→真实名→值）
check_tengu() {
    local tengu="$1"
    local real_name="${TENGU_FLAGS[$tengu]}"
    if [ -z "$real_name" ]; then
        echo "unknown_flag"
        return
    fi
    local value=$(get_flag "$real_name")
    echo "$real_name=$value"
}

# 列出所有flags（翻译后）
list_flags() {
    echo "=== OpenClaw Feature Flags (20) ==="
    echo ""
    for tengu in "${!TENGU_FLAGS[@]}"; do
        real="${TENGU_FLAGS[$tengu]}"
        status=$(get_flag "$real")
        
        # 根据状态显示emoji
        case "$status" in
            true|enabled|on) icon="✅" ;;
            false|disabled|off) icon="❌" ;;
            undefined) icon="⬜" ;;
            *) icon="📌" ;;
        esac
        
        # 按tier分组
        tier="?"
        case "$tengu" in
            tengu_passport*|tengu_moth*|tengu_bramble_w*|tengu_wren*)
                tier="💾 Memory" ;;
            tengu_kairos*|tengu_iris*|tengu_bramble_l*|tengu_finch*)
                tier="⚡ Autonomy" ;;
            tengu_larch*|tengu_dunlin*|tengu_amber*|tengu_coral*|tengu_slate*|tengu_heron*)
                tier="🔒 Security" ;;
            tengu_merlin*|tengu_oriole*|tengu_vireo*|tengu_fennel*|tengu_kestrel*|tengu_tern*)
                tier="🎨 UI/Output" ;;
        esac
        
        printf "%s %-20s %s\n" "$icon" "$real" "$tier"
        printf "   tengu: %s\n\n" "$tengu"
    done
}

# 批量启用/禁用
batch_set() {
    local pattern="$1"
    local value="$2"
    
    case "$pattern" in
        memory)
            set_flag "memory_extraction_gate" "$value"
            set_flag "memory_extraction_enable" "$value"
            set_flag "memory_extraction_freq" "60"
            ;;
        autonomy)
            set_flag "proactive_mode" "$value"
            set_flag "agent_trigger_enable" "$value"
            ;;
        security)
            set_flag "permission_auto_mode" "$value"
            set_flag "tool_validation_strict" "$value"
            ;;
        all)
            for real in "${TENGU_FLAGS[@]}"; do
                set_flag "$real" "$value" 2>/dev/null
            done
            ;;
    esac
}

# 获取flag的tengu名
get_tengu_name() {
    local real="$1"
    for tengu in "${!TENGU_FLAGS[@]}"; do
        if [ "${TENGU_FLAGS[$tengu]}" = "$real" ]; then
            echo "$tengu"
            return
        fi
    done
    echo "unknown"
}

# 导出所有tengu名（用于日志不泄露真实功能）
export_tengu_flags() {
    echo "# Feature Flag Export (tengu format)"
    for tengu in "${!TENGU_FLAGS[@]}"; do
        local real="${TENGU_FLAGS[$tengu]}"
        local value=$(get_flag "$real")
        echo "${tengu}=${value}"
    done
}

# 初始化默认flags
init_defaults() {
    python3 << EOF
import json, os

db = os.path.expanduser('$FEATURE_DB')
defaults = {
    # Memory
    "memory_extraction_gate": "true",
    "memory_extraction_enable": "true",
    "memory_extraction_freq": "60",
    "context_compact_threshold": "60",
    
    # Autonomy
    "proactive_mode": "false",
    "autonomous_tick_interval": "300",
    "agent_trigger_enable": "false",
    "self_dream_enable": "false",
    
    # Security
    "permission_auto_mode": "auto",
    "subagent_isolation": "true",
    "json_tool_format": "false",
    "tool_validation_strict": "false",
    "exec_timeout_max": "50",
    "path_whitelist_strict": "true",
    
    # UI/Output
    "terminal_ui_enable": "false",
    "streaming_response": "false",
    "magic_docs_auto_save": "true",
    "compact_on_high_context": "true",
    "team_memory_sync": "false",
    "heartbeat_verbose": "false",
}

flags = {}
if os.path.exists(db):
    try:
        with open(db, 'r') as f:
            flags = json.load(f)
    except: pass

# 合并defaults（不覆盖已有）
for k, v in defaults.items():
    if k not in flags:
        flags[k] = v

with open(db, 'w') as f:
    json.dump(flags, f, indent=2)
print("Initialized defaults")
EOF
}

# 主路由
case "$1" in
    get)    shift; get_flag "$@" ;;
    set)    shift; set_flag "$@" ;;
    check)  shift; check_tengu "$@" ;;
    list)   list_flags ;;
    batch)  shift; batch_set "$@" ;;
    tengu)  shift; get_tengu_name "$@" ;;
    export) export_tengu_flags ;;
    init)   init_defaults ;;
    *) 
        echo "Feature Flags - Tengu System"
        echo "Usage: $0 <command> [args...]"
        echo ""
        echo "Commands:"
        echo "  get <flag>            - Get flag value"
        echo "  set <flag> <value>    - Set flag value"
        echo "  check <tengu_name>    - Check via tengu name"
        echo "  list                  - List all flags"
        echo "  batch <pattern> <val> - Batch set (memory|security|autonomy|all)"
        echo "  tengu <real_name>     - Get tengu name for real name"
        echo "  export                - Export all as tengu (for logs)"
        echo "  init                  - Initialize defaults"
        echo ""
        echo "Note: Use tengu names in logs to avoid leaking feature names"
        ;;
esac
