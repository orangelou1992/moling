#!/bin/bash
# remember.sh - 写入记忆到文件和数据库
# 用法: remember.sh "记忆内容" "tag1|tag2" confidence

CONTENT="$1"
TAGS="${2:-general}"
CONF="${3:-0.8}"

if [ -z "$CONTENT" ]; then
    echo "用法: remember.sh \"记忆内容\" \"tags\" confidence"
    exit 1
fi

TODAY=$(date +%Y-%m-%d)
MEMORY_FILE="$HOME/.openclaw/workspace/memory/$TODAY.md"
DB="$HOME/.agent-memory/memory.db"

# 不存在则创建（事件驱动，不需要cron）
if [ ! -f "$MEMORY_FILE" ]; then
    echo "# $TODAY 日记" > "$MEMORY_FILE"
    echo "Created by remember.sh on demand" >> "$MEMORY_FILE"
fi

# 写入当天日记文件
echo "- $CONTENT" >> "$MEMORY_FILE"

# 写入数据库
python3 -c "
import sqlite3, sys, time
conn = sqlite3.connect('$DB')
c = conn.cursor()
ts = int(time.time())
c.execute('INSERT INTO facts (content, tags, confidence, created_at, last_accessed, access_count) VALUES (?, ?, ?, ?, ?, ?)',
    ('$CONTENT', '$TAGS', $CONF, ts, ts, 0))
conn.commit()
conn.close()
print('已写入: $CONTENT')
"
