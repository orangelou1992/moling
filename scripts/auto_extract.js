/**
 * auto_extract.js - 从exec输出中自动提取代码片段
 * Claude Code的MagicDocs + auto_extract复刻
 * 
 * 功能：
 * 1. 从exec结果中识别代码块
 * 2. 自动保存有价值的代码片段到artifacts
 * 3. 提取关键信息到memory
 * 
 * 用法：
 *   node auto_extract.js < exec_output.txt
 *   echo "$output" | node auto_extract.js
 *   node auto_extract.js --file /path/to/output.txt
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

// 配置
let HOME;
try { HOME = require('os').homedir(); } catch(e) { HOME = '/home/louyz'; }
const ARTIFACTS_DIR = path.join(HOME, '.openclaw/workspace/memory/artifacts');
const INDEX_FILE = path.join(ARTIFACTS_DIR, '.index.json');

// 支持的语言模式
const LANGUAGE_PATTERNS = {
    javascript: /\b(const|let|var|function|=>|async|await|import|export|require)\b/,
    typescript: /\b(interface|type|enum|namespace|declare|as|readonly)\b/,
    python: /\b(def|class|import|from|if __name__|print\(|lambda|async def)\b/,
    bash: /\b(#!|if \[|fi|then|else|echo|export|source)\b/,
    json: /^\s*[{\[]/,
    sql: /\b(SELECT|INSERT|UPDATE|DELETE|CREATE|DROP|FROM|WHERE|JOIN)\b/i,
    html: /<(html|head|body|div|span|script|style)<[^>]*>/i,
    css: /[.#][\w-]+\s*\{|@media|@import|flex|grid|margin|padding/,
    yaml: /^\w+:\s*$/m,
    markdown: /^#{1,6}\s+|^[*\-]\s|^```/m,
};

// 优先级模式（高优先级片段特征）
const HIGH_VALUE_PATTERNS = [
    /\b(function|def|class|interface|type|struct)\s+\w+/g,
    /\b(const|let|var|export|import|from|require)\s+\w+\s*=/g,
    /^#!.*$/gm,
    /\bTODO\b|\bFIXME\b|\bHACK\b|\bXXX\b/g,
    /\b(claude|openclaw|agent)\s*:\s*/gi
];

// 代码块检测
function detectCodeBlocks(text) {
    const blocks = [];
    
    // 1. fenced code blocks (```lang ... ```)
    const fencedRegex = /```(\w*)\n([\s\S]*?)```/g;
    let match;
    while ((match = fencedRegex.exec(text)) !== null) {
        blocks.push({
            lang: match[1] || detectLanguage(match[2]),
            content: match[2].trim(),
            type: 'fenced',
            start: match.index,
            end: match.index + match[0].length,
        });
    }
    
    // 2. indentation-based code blocks (行首有缩进且多行)
    const indentedRegex = /^((?: {4}|\t)[^\n]+\n)+/gm;
    while ((match = indentedRegex.exec(text)) !== null) {
        const content = match[0];
        // 跳过已被fenced覆盖的区域
        const overlaps = blocks.some(b => match.index >= b.start && match.index < b.end);
        if (!overlaps && content.split('\n').length >= 2) {
            blocks.push({
                lang: detectLanguage(content),
                content: content.trim(),
                type: 'indented',
                start: match.index,
                end: match.index + match[0].length,
            });
        }
    }
    
    return blocks;
}

// 语言检测
function detectLanguage(code) {
    if (!code || code.length < 10) return 'text';
    
    for (const [lang, pattern] of Object.entries(LANGUAGE_PATTERNS)) {
        if (pattern.test(code)) return lang;
    }
    return 'text';
}

// 评估代码块价值
function scoreBlock(block) {
    let score = 0;
    
    // 长度评分
    const lines = block.content.split('\n').length;
    score += Math.min(lines * 2, 40);
    
    // 字数评分
    score += Math.min(block.content.length / 50, 30);
    
    // 高价值模式匹配
    for (const pattern of HIGH_VALUE_PATTERNS) {
        if (pattern.test(block.content)) score += 10;
    }
    
    // shebang
    if (block.content.startsWith('#!')) score += 20;
    
    // 函数定义
    if (/^\s*(function|def|const|let|var)\s+\w+/m.test(block.content)) score += 15;
    
    return score;
}

// 保存到artifacts
async function saveArtifact(content, language, description, type = 'output') {
    const artifactId = `art_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
    const ext = {
        javascript: 'js', typescript: 'ts', python: 'py', bash: 'sh',
        json: 'json', sql: 'sql', html: 'html', css: 'css', text: 'txt'
    }[language] || 'txt';
    
    const filepath = path.join(ARTIFACTS_DIR, `${artifactId}.${ext}`);
    
    // 确保目录存在
    if (!fs.existsSync(ARTIFACTS_DIR)) {
        fs.mkdirSync(ARTIFACTS_DIR, { recursive: true });
    }
    
    fs.writeFileSync(filepath, content);
    
    // 更新索引
    let index = { artifacts: [], last_updated: null };
    if (fs.existsSync(INDEX_FILE)) {
        try {
            index = JSON.parse(fs.readFileSync(INDEX_FILE, 'utf8'));
        } catch (e) {}
    }
    
    index.artifacts.unshift({
        id: artifactId,
        type,
        language,
        description,
        filepath,
        size: content.length,
        created: new Date().toISOString(),
        tags: [],
        auto_extracted: true,
    });
    index.last_updated = new Date().toISOString();
    
    fs.writeFileSync(INDEX_FILE, JSON.stringify(index, null, 2));
    
    return artifactId;
}

// 提取关键信息
function extractKeyInfo(text) {
    const info = {
        files_created: [],
        files_modified: [],
        commands_run: [],
        errors: [],
        decisions: [],
    };
    
    // 文件操作
    const fileCreateRe = /(?:create|write|touch|mkdir)\s+['"]?([^\s'"…]+)['"]?/gi;
    let m;
    while ((m = fileCreateRe.exec(text)) !== null) info.files_created.push(m[1]);
    
    const fileModRe = /(?:edit|modify|update|changed?)\s+['"]?([^\s'"…]+)['"]?/gi;
    while ((m = fileModRe.exec(text)) !== null) info.files_modified.push(m[1]);
    
    // 命令
    const cmdRe = /\$?\s*(?:npx|npm|yarn|pnpm|node|python|pip|git|bash|sh)\s+[^\n]+/g;
    while ((m = cmdRe.exec(text)) !== null) {
        info.commands_run.push(m[0].trim().slice(0, 100));
    }
    
    // 错误
    const errRe = /(?:error|Error|ERROR|failed|FAILED|Failed|exception|Exception)[:\s]+([^\n]+)/gi;
    while ((m = errRe.exec(text)) !== null) info.errors.push(m[1].trim().slice(0, 100));
    
    // 决策（Claude风格）
    const decRe = /(?:Decision|决定|choice|选择)[:\s]*([^\n]+)/gi;
    while ((m = decRe.exec(text)) !== null) info.decisions.push(m[1].trim());
    
    return info;
}

// 主处理函数
async function analyzeText(text) {
    const results = {
        artifacts_saved: [],
        key_info: null,
        stats: { blocks_found: 0, blocks_saved: 0 },
    };
    
    const blocks = detectCodeBlocks(text);
    results.stats.blocks_found = blocks.length;
    
    // 按价值排序，保存最高价值的
    const scored = blocks.map(b => ({ ...b, score: scoreBlock(b) }));
    scored.sort((a, b) => b.score - a.score);
    
    // 只保存前5个最有价值的
    for (const block of scored.slice(0, 5)) {
        if (block.score < 10) continue;
        
        try {
            const id = await saveArtifact(
                block.content,
                block.lang,
                `Auto-extracted ${block.lang} code (score=${block.score})`,
                'output'
            );
            results.artifacts_saved.push({ id, lang: block.lang, score: block.score });
            results.stats.blocks_saved++;
        } catch (e) {
            // 静默失败
        }
    }
    
    // 提取关键信息
    results.key_info = extractKeyInfo(text);
    
    return results;
}

// CLI入口
async function main() {
    let input = '';
    
    const argv = typeof process !== 'undefined' && process.argv ? process.argv : [];
    const hasArg = (arg) => argv.includes(arg);
    
    if (hasArg('--file')) {
        const idx = argv.indexOf('--file');
        const filepath = argv[idx + 1];
        if (filepath && fs.existsSync(filepath)) {
            input = fs.readFileSync(filepath, 'utf8');
        }
    } else if (hasArg('--help') || hasArg('-h')) {
        console.log('Usage: auto_extract.js [options]');
        console.log('  --file <path>  Read from file');
        console.log('  --stats        Show statistics only');
        console.log('  Reads from stdin if no --file specified');
        return;
    } else if (hasArg('--stats')) {
        // 只显示统计
        let idx = { artifacts: 0, total_size: 0 };
        if (fs.existsSync(INDEX_FILE)) {
            try {
                const data = JSON.parse(fs.readFileSync(INDEX_FILE, 'utf8'));
                idx = data;
            } catch (e) {}
        }
        console.log(JSON.stringify({
            total: idx.artifacts?.length || 0,
            total_size: idx.artifacts?.reduce((s, a) => s + (a.size || 0), 0) || 0,
            last_updated: idx.last_updated,
            auto_extracted: idx.artifacts?.filter(a => a.auto_extracted).length || 0,
        }, null, 2));
        return;
    } else {
        // 从stdin读取
        try {
            input = fs.readFileSync('/dev/stdin', 'utf8');
        } catch (e) {
            console.error('No input. Use --file or pipe data.');
            return;
        }
    }
    
    const results = await analyzeText(input);
    
    // 输出结果
    if (results.artifacts_saved.length > 0) {
        console.log(`\n🧠 MagicDocs auto-extracted ${results.stats.blocks_saved} code blocks:`);
        for (const a of results.artifacts_saved) {
            console.log(`  • ${a.id} (${a.lang}, score=${a.score})`);
        }
    }
    
    if (results.key_info) {
        const ki = results.key_info;
        if (ki.commands_run.length > 0) {
            console.log(`\n📋 Commands run: ${ki.commands_run.length}`);
        }
        if (ki.errors.length > 0) {
            console.log(`\n⚠️  Errors detected: ${ki.errors.length}`);
            ki.errors.slice(0, 3).forEach(e => console.log(`  • ${e}`));
        }
    }
    
    // JSON输出（供调用者解析）
    const argv2 = typeof process !== 'undefined' && process.argv ? process.argv : [];
    if (argv2.includes('--json')) {
        console.log('\n--- JSON OUTPUT ---');
        console.log(JSON.stringify(results, null, 2));
    }
}

main().catch(e => {
    console.error('auto_extract error:', e.message);
    throw e;
});
