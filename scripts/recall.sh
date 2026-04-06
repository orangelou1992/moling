#!/bin/bash
# recall.sh - 检索记忆
# 用法: recall.sh "关键词"

QUERY="${1:-}"
DB="$HOME/.agent-memory/memory.db"

if [ -z "$QUERY" ]; then
    echo "用法: recall.sh \"关键词\""
    exit 1
fi

python3 -c "
import sqlite3
conn = sqlite3.connect('$DB')
c = conn.cursor()
c.execute(\"SELECT content, tags, confidence FROM facts WHERE content LIKE '%$QUERY%' ORDER BY confidence DESC, last_accessed DESC\")
results = c.fetchall()
if results:
    for content, tags, conf in results:
        print(f'[{conf}] {content}')
        print(f'  tags: {tags}')
        print()
else:
    print('没找到相关记忆')
conn.close()
"
