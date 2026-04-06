#!/bin/bash
# team_memory.sh - 多Agent共享记忆系统
# Claude Code的Team Memory复刻
#
# Claude Code原文设计：
# - Session开始时读取team memory
# - File changes触发更新
# - 存储在memory/team/
#
# 本实现：跨session共享知识，支持多agent访问

TEAM_DIR="$HOME/.openclaw/workspace/.team_memory"
INDEX_FILE="$TEAM_DIR/.index.json"
mkdir -p "$TEAM_DIR"

# ========== 核心类型 ==========

# Project Memory - 项目级共享知识
# 用途：所有agent共享的项目上下文

# Agent Memory - 各agent的专用知识
# 用途：单个agent的偏好、工作方式

# Shared Facts - 跨agent的事实库
# 用途：通用知识、API信息、配置

# ========== 保存到team memory ==========
# 用法: team_memory.sh save <type> <key> <content>
#   type: project|agent|fact|decision|reference
#   key:  唯一标识符

save_to_team() {
    local type="$1"
    local key="$2"
    local content
    shift 2
    
    if [ -p /dev/stdin ]; then
        content=$(cat /dev/stdin)
    else
        content="$*"
    fi
    
    [ -z "$key" ] && { echo "ERROR: no key specified"; return 1; }
    [ -z "$content" ] && { echo "WARN: empty content, skipping"; return 0; }
    
    local safe_key=$(echo "$key" | tr ' /' '_-' | tr -cd '[:alnum:]_-')
    local ext="txt"
    case "$type" in
        project) ext="md" ;;
        agent) ext="md" ;;
        fact) ext="json" ;;
        decision) ext="md" ;;
        reference) ext="txt" ;;
    esac
    
    local filepath="$TEAM_DIR/${type}_${safe_key}.${ext}"
    echo "$content" > "$filepath"
    
    # 更新索引
    python3 << EOF
import json, os
from datetime import datetime

index_file = os.path.expanduser('$INDEX_FILE')
team_dir = os.path.expanduser('$TEAM_DIR')

index = {"entries": [], "last_updated": None}
if os.path.exists(index_file):
    try:
        with open(index_file, 'r') as f:
            index = json.load(f)
    except: pass

# 移除旧条目（同名key）
index["entries"] = [e for e in index.get("entries", []) if e.get("key") != "$key"]

entry = {
    "type": "$type",
    "key": "$key",
    "filepath": "$filepath",
    "size": len("""$content"""),
    "created": datetime.now().isoformat(),
    "updated": datetime.now().isoformat(),
    "author": "墨瞳",
}
index["entries"].insert(0, entry)
index["last_updated"] = datetime.now().isoformat()

with open(index_file, 'w') as f:
    json.dump(index, f, indent=2, ensure_ascii=False)
print(f"Saved to team memory: [$type] $key")
EOF
    
    return 0
}

# ========== 查询team memory ==========
# 用法: team_memory.sh query <query> [type]
query_team() {
    local query="$1"
    local type_filter="${2:-}"
    
    python3 << EOF
import json, os

index_file = os.path.expanduser('$INDEX_FILE')
team_dir = os.path.expanduser('$TEAM_DIR')

if not os.path.exists(index_file):
    print("Team memory empty")
    import sys; sys.exit(0)

with open(index_file, 'r') as f:
    index = json.load(f)

q = "$query".lower()
results = []
for e in index.get("entries", []):
    if "$type_filter" and e.get("type") != "$type_filter":
        continue
    key = e.get("key", "").lower()
    if q in key or q in e.get("type", "").lower():
        filepath = os.path.expanduser(e["filepath"])
        if os.path.exists(filepath):
            content = open(filepath).read()[:500]
        else:
            content = "[file not found]"
        results.append({
            **e,
            "preview": content
        })

if not results:
    print("No matching team memory")
else:
    for r in results[:10]:
        print(f"[{r['type']}] {r['key']} ({r.get('size', 0)} bytes)")
        print(f"  {r.get('preview', '')[:100]}...")
        print()
EOF
}

# ========== 读取特定条目 ==========
# 用法: team_memory.sh read <type> <key>
read_from_team() {
    local type="$1"
    local key="$2"
    
    local safe_key=$(echo "$key" | tr ' /' '_-' | tr -cd '[:alnum:]_-')
    local filepath="$TEAM_DIR/${type}_${safe_key}.${ext}"
    
    # 查找实际文件
    local found
    found=$(find "$TEAM_DIR" -name "${type}_${safe_key}.*" -type f 2>/dev/null | head -1)
    
    if [ -n "$found" ] && [ -f "$found" ]; then
        cat "$found"
    else
        echo "Not found: [$type] $key"
        return 1
    fi
}

# ========== 列出team memory ==========
# 用法: team_memory.sh list [type]
list_team() {
    local type_filter="${1:-}"
    python3 << EOF
import json, os

index_file = os.path.expanduser('$INDEX_FILE')
if not os.path.exists(index_file):
    print("Team memory empty"); exit(0)

with open(index_file, 'r') as f:
    index = json.load(f)

entries = index.get("entries", [])
if "$type_filter":
    entries = [e for e in entries if e.get("type") == "$type_filter"]

print(f"Team Memory: {len(entries)} entries")
print()
for e in entries[:20]:
    print(f"[{e['type']}] {e['key']}")
    print(f"    size={e.get('size', 0)}b, updated={e.get('updated', '')[:19]}")
EOF
}

# ========== 删除条目 ==========
# 用法: team_memory.sh delete <type> <key>
delete_from_team() {
    local type="$1"
    local key="$2"
    
    python3 << EOF
import json, os

index_file = os.path.expanduser('$INDEX_FILE')
team_dir = os.path.expanduser('$TEAM_DIR')

safe_key = "$key".translate(str.maketrans(' /', '--')).translate({ord(c): None for c in '.:;!?@#$%^&*()[]{}|<>'})
safe_key = ''.join(c for c in safe_key if c.isalnum() or c in '_-')

if not os.path.exists(index_file):
    print("No index"); exit(0)

with open(index_file, 'r') as f:
    index = json.load(f)

removed = []
new_entries = []
for e in index.get("entries", []):
    if e.get("type") == "$type" and e.get("key") == "$key":
        filepath = os.path.expanduser(e.get("filepath", ""))
        if os.path.exists(filepath):
            os.remove(filepath)
        removed.append(e.get("key"))
    else:
        new_entries.append(e)

if removed:
    index["entries"] = new_entries
    with open(index_file, 'w') as f:
        json.dump(index, f, indent=2)
    print(f"Deleted: {', '.join(removed)}")
else:
    print("Not found: [$type] $key")
EOF
}

# ========== 初始化project memory ==========
# 用法: team_memory.sh init-project
init_project() {
    if [ ! -f "$TEAM_DIR/project_README.md" ]; then
        cat > "$TEAM_DIR/project_README.md" << 'EOF'
# Team Memory - 项目共享知识

本目录存储跨agent共享的项目知识。

## 类型
- `project_*`: 项目级知识
- `agent_*`: agent个人知识
- `fact_*`: 通用事实
- `decision_*`: 决策记录
- `reference_*`: 参考信息

## 使用方式
```bash
# 保存
team_memory.sh save project my-project "项目描述"

# 查询
team_memory.sh query "关键词"

# 读取
team_memory.sh read project my-project

# 列出
team_memory.sh list
```
EOF
        echo "✅ Initialized team memory"
    else
        echo "Team memory already initialized"
    fi
}

# ========== 与主memory同步 ==========
# 用法: team_memory.sh sync-to-memory
sync_to_memory() {
    python3 << EOF
import json, os
from datetime import datetime

index_file = os.path.expanduser('$INDEX_FILE')
mem_file = os.path.expanduser('$HOME/.openclaw/workspace/memory/$(date "+%Y-%m-%d").md')
os.makedirs(os.path.dirname(mem_file), exist_ok=True)

if not os.path.exists(index_file):
    print("No team memory to sync"); exit(0)

with open(index_file, 'r') as f:
    index = json.load(f)

entries = index.get("entries", [])[:20]  # 只同步最近20条

existing = ""
if os.path.exists(mem_file):
    existing = open(mem_file).read()

new_content = f"""

## Team Memory Sync ({datetime.now().strftime("%Y-%m-%d %H:%M")})
"""
for e in entries:
    new_content += f"- [{e['type']}] {e['key']} (updated: {e.get('updated', '')[:19]})\n"

new_content += "\n"

with open(mem_file, 'a') as f:
    f.write(new_content)

print(f"Synced {len(entries)} entries to memory")
EOF
}

# ========== 主路由 ==========
case "${1:-}" in
    save)       shift; save_to_team "$@" ;;
    query)      shift; query_team "$@" ;;
    read)       shift; read_from_team "$@" ;;
    list)       shift; list_team "$@" ;;
    delete)     shift; delete_from_team "$@" ;;
    init)       init_project ;;
    sync)       sync_to_memory ;;
    *)
        echo "Team Memory - Multi-Agent Shared Knowledge"
        echo "Usage: $0 <command> [args...]"
        echo ""
        echo "Commands:"
        echo "  save <type> <key> [content]  - Save to team memory"
        echo "  query <query> [type]         - Search team memory"
        echo "  read <type> <key>            - Read specific entry"
        echo "  list [type]                  - List entries"
        echo "  delete <type> <key>           - Delete entry"
        echo "  init                         - Initialize project memory"
        echo "  sync                         - Sync to daily memory"
        echo ""
        echo "Types: project, agent, fact, decision, reference"
        ;;
esac
