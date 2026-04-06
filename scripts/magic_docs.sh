#!/bin/bash
# magic_docs.sh - Claude Code的持久化Artifacts系统复刻
# 生成大段代码/文档时自动存储，不丢失
# 
# Claude Code原文设计：
# - MagicDocs: 对话闲时自动维护repo内.md文件
# - 本实现：存储生成的代码片段到memory/artifacts/，可检索

ARTIFACTS_DIR="$HOME/.openclaw/workspace/memory/artifacts"
INDEX_FILE="$ARTIFACTS_DIR/.index.json"
mkdir -p "$ARTIFACTS_DIR"

# ========== 核心功能 ==========

# 保存一个artifact
# 用法: magic_docs.sh save <type> <filename> [language] [description]
#   type: code|doc|config|output|summary
#   filename: 保存的文件名
#   language: 代码语言（可选）
#   description: 简短描述（可选）
save_artifact() {
    local type="$1"
    local filename="$2"
    local language="${3:-}"
    local description="${4:-}"
    local content
    local artifact_id
    
    # 从stdin读取内容，或从文件
    if [ -p /dev/stdin ]; then
        content=$(cat /dev/stdin)
    else
        echo "ERROR: No content provided via stdin"
        return 1
    fi
    
    [ -z "$content" ] && echo "WARN: empty artifact, skipping" && return 0
    
    artifact_id="art_$(date '+%Y%m%d_%H%M%S')_$$"
    local ext
    case "$language" in
        javascript|js) ext="js" ;;
        typescript|ts) ext="ts" ;;
        python|py) ext="py" ;;
        bash|sh) ext="sh" ;;
        json) ext="json" ;;
        markdown|md) ext="md" ;;
        html) ext="html" ;;
        css) ext="css" ;;
        sql) ext="sql" ;;
        *) ext="txt" ;;
    esac
    
    local filepath="$ARTIFACTS_DIR/${artifact_id}.${ext}"
    echo "$content" > "$filepath"
    
    # 更新索引
    python3 << EOF
import json, os, sys
from datetime import datetime

index_file = os.path.expanduser('$INDEX_FILE')
artifacts_dir = os.path.expanduser('$ARTIFACTS_DIR')

index = {"artifacts": [], "last_updated": None}
if os.path.exists(index_file):
    try:
        with open(index_file, 'r') as f:
            index = json.load(f)
    except: pass

entry = {
    "id": "$artifact_id",
    "type": "$type",
    "language": "$language",
    "description": "$description",
    "filename": "$filename",
    "filepath": "$filepath",
    "size": len("""$content"""),
    "created": datetime.now().isoformat(),
    "tags": []
}
index["artifacts"].insert(0, entry)
index["last_updated"] = datetime.now().isoformat()

with open(index_file, 'w') as f:
    json.dump(index, f, indent=2, ensure_ascii=False)
print(f"Saved: $artifact_id")
EOF
    
    echo "✅ MagicDocs: saved $artifact_id ($type, $language) → $filepath"
    echo "$artifact_id"
}

# 搜索artifacts
# 用法: magic_docs.sh search <query> [type] [limit]
search_artifacts() {
    local query="$1"
    local type_filter="${2:-}"
    local limit="${3:-10}"
    
    python3 << EOF
import json, os, sys, re

index_file = os.path.expanduser('$INDEX_FILE')
artifacts_dir = os.path.expanduser('$ARTIFACTS_DIR')

if not os.path.exists(index_file):
    print("No artifacts found")
    sys.exit(0)

with open(index_file, 'r') as f:
    index = json.load(f)

results = []
for art in index.get("artifacts", []):
    # 类型过滤
    if "$type_filter" and art.get("type") != "$type_filter":
        continue
    
    # 搜索匹配
    q = "$query".lower()
    if (q in art.get("description", "").lower() or
        q in art.get("filename", "").lower() or
        q in art.get("language", "").lower() or
        any(q in tag.lower() for tag in art.get("tags", []))):
        results.append(art)

results = results[:int("$limit")]

if not results:
    print("No matching artifacts")
else:
    for r in results:
        print(f"[{r['id']}] {r['type']} | {r['filename']} | {r['language']} | {r['description']}")
        print(f"   → {r['filepath']} ({r['size']} bytes, {r['created'][:19]})")
        print()
EOF
}

# 读取一个artifact
# 用法: magic_docs.sh read <artifact_id>
read_artifact() {
    local artifact_id="$1"
    python3 << EOF
import json, os

index_file = os.path.expanduser('$INDEX_FILE')
if not os.path.exists(index_file):
    print("No artifacts found")
    sys.exit(1)

with open(index_file, 'r') as f:
    index = json.load(f)

for art in index.get("artifacts", []):
    if art["id"] == "$artifact_id":
        filepath = os.path.expanduser(art["filepath"])
        if os.path.exists(filepath):
            with open(filepath, 'r') as f:
                print(f.read())
        else:
            print(f"ERROR: file not found: {filepath}")
        break
else:
    print(f"Artifact not found: $artifact_id")
EOF
}

# 列出所有artifacts
# 用法: magic_docs.sh list [type] [limit]
list_artifacts() {
    local type_filter="${1:-}"
    local limit="${2:-20}"
    search_artifacts "" "$type_filter" "$limit"
}

# 删除旧artifact（自动清理，超过30天的）
# 用法: magic_docs.sh cleanup [days]
cleanup_artifacts() {
    local days="${1:-30}"
    python3 << EOF
import json, os, sys
from datetime import datetime, timedelta

index_file = os.path.expanduser('$INDEX_FILE')
artifacts_dir = os.path.expanduser('$ARTIFACTS_DIR')
cutoff = datetime.now() - timedelta(days=int("$days"))

if not os.path.exists(index_file):
    sys.exit(0)

with open(index_file, 'r') as f:
    index = json.load(f)

kept = []
removed = 0
for art in index.get("artifacts", []):
    created = datetime.fromisoformat(art["created"])
    if created > cutoff:
        kept.append(art)
    else:
        filepath = os.path.expanduser(art["filepath"])
        if os.path.exists(filepath):
            os.remove(filepath)
        removed += 1

index["artifacts"] = kept
with open(index_file, 'w') as f:
    json.dump(index, f, indent=2)

print(f"Cleanup: removed {removed} artifacts older than {days} days")
EOF
}

# 添加tag到artifact
# 用法: magic_docs.sh tag <artifact_id> <tag>
tag_artifact() {
    local artifact_id="$1"
    local tag="$2"
    python3 << EOF
import json, os

index_file = os.path.expanduser('$INDEX_FILE')
if not os.path.exists(index_file):
    print("No artifacts found")
    sys.exit(1)

with open(index_file, 'r') as f:
    index = json.load(f)

for art in index.get("artifacts", []):
    if art["id"] == "$artifact_id":
        if "tags" not in art:
            art["tags"] = []
        if "$tag" not in art["tags"]:
            art["tags"].append("$tag")
        with open(index_file, 'w') as f:
            json.dump(index, f, indent=2)
        print(f"Added tag '$tag' to $artifact_id")
        break
else:
    print(f"Artifact not found: $artifact_id")
EOF
}

# 统计信息
stats_artifact() {
    python3 << EOF
import json, os

index_file = os.path.expanduser('$INDEX_FILE')
if not os.path.exists(index_file):
    print("No artifacts")
    sys.exit(0)

with open(index_file, 'r') as f:
    index = json.load(f)

arts = index.get("artifacts", [])
total_size = sum(a.get("size", 0) for a in arts)
types = {}
for a in arts:
    t = a.get("type", "unknown")
    types[t] = types.get(t, 0) + 1

print(f"Total artifacts: {len(arts)}")
print(f"Total size: {total_size:,} bytes ({total_size/1024:.1f} KB)")
for t, c in sorted(types.items()):
    print(f"  {t}: {c}")
EOF
}

# ========== 主路由 ==========
case "${1:-}" in
    save)   shift; save_artifact "$@" ;;
    search) shift; search_artifacts "$@" ;;
    read)   shift; read_artifact "$@" ;;
    list)   shift; list_artifacts "$@" ;;
    tag)    shift; tag_artifact "$@" ;;
    cleanup) shift; cleanup_artifacts "$@" ;;
    stats)  stats_artifact ;;
    *) 
        echo "MagicDocs - Claude Code Artifacts System"
        echo "Usage: $0 <command> [args...]"
        echo ""
        echo "Commands:"
        echo "  save <type> <filename> [lang] [desc]  - Save artifact (stdin)"
        echo "  search <query> [type] [limit]        - Search artifacts"
        echo "  read <artifact_id>                   - Read artifact content"
        echo "  list [type] [limit]                  - List artifacts"
        echo "  tag <artifact_id> <tag>              - Add tag"
        echo "  cleanup [days]                        - Remove old artifacts"
        echo "  stats                                 - Show statistics"
        ;;
esac
