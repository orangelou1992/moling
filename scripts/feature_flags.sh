#!/bin/bash
# feature_flags.sh - Feature Flag 管理
# Claude Code启发，但用真实名字，不用混淆命名

FLAGS_DB="${HOME}/.openclaw/feature_flags.json"

get_flag() {
    python3 -c "
import json
try:
    with open('$FLAGS_DB') as f: flags = json.load(f)
    print(flags.get('$1', 'off'))
except: print('off')
" 2>/dev/null
}

set_flag() {
    python3 -c "
import json, os
db = '$FLAGS_DB'
flags = json.load(open(db)) if os.path.exists(db) else {}
flags['$1'] = '$2'
json.dump(flags, open(db, 'w'), indent=2)
print(f'$1 = $2')
" 2>/dev/null
}

list_flags() {
    echo "=== Feature Flags ==="
    python3 -c "
import json
try:
    flags = json.load(open('$FLAGS_DB'))
    for k, v in sorted(flags.items()):
        status = '\033[32mON \033[0m' if v == 'true' else '\033[31mOFF\033[0m' if v == 'false' else str(v)
        print(f'  {k:40s} {status}')
except: pass
" 2>/dev/null
}

case "$1" in
    get) get_flag "$2" ;;
    set) set_flag "$2" "$3" ;;
    list|'') list_flags ;;
    *) echo "Usage: feature_flags.sh {get|set|list}" ;;
esac
