# Claude Code vs OpenClaw 架构完整对比

_来源：Claude Code泄露源码分析 + OpenClaw当前架构_
_时间：2026-04-06_

---

## 泄露事件

- **日期**：2026-03-31
- **源头**：npm registry 发布的 .map 文件（sourcemap）
- **规模**：1,900文件，512,000+行TypeScript
- **技术栈**：Bun + React/Ink + TypeScript严格模式 + Commander.js + Zod v4 + ripgrep + MCP + LSP + gRPC + OpenTelemetry + GrowthBook

---

## 核心架构对比

| 维度 | Claude Code | OpenClaw (墨瞳) |
|------|-------------|-----------------|
| **运行时** | Bun (JS/Zig) | Node.js v22 |
| **核心循环** | QueryEngine streaming | Agent Loop (via LLM) |
| **流式** | 完整streaming输出 | HTTP API (no streaming) |
| **UI** | React + Ink (terminal UI) | Web UI + Channel plugins |
| **进程模型** | 主进程 + puppet子进程 | Gateway daemon + agent sessions |
| **语言** | TypeScript strict | TypeScript (OpenClaw) + Python (skills) |
| **包管理** | npm (Bun) | npm + pip |

---

## Agent Loop 机制

### Claude Code
```
QueryEngine.runQuery()
 ├─ buildQueryContext()
 │   ├─ loadProjectContext()     // .md, .claude/, .git/
 │   ├─ buildSystemPrompt()      // 合规/风格/工具说明
 │   ├─ normalizeMessages()       // 14步消息正规化
 │   └─ loadMemories()            // 6个子系统
 ├─ model.generate()              // streaming
 ├─ parseModeBlock()              // <answer>/<diplomacy>等
 ├─ executeTools()                // 10层执行管道
 │   ├─ parseToolCalls()
 │   ├─ loadDeferredTools()       // 延迟加载
 │   ├─ resolveMcpServers()
 │   ├─ applyToolHooks()          // pre-tool hooks
 │   ├─ checkPermissions()         // 4级权限
 │   ├─ executeAll()              // 并发执行
 │   ├─ applyResultHooks()
 │   └─ processResults()
 └─ loopUntilEnd()               // 自然结束/abort/maxTurns
```

### OpenClaw
```
Agent.runTurn()
 ├─ loadContext()               // memory files
 ├─ buildPrompt()               // system + memory
 ├─ model.complete()           // HTTP API
 ├─ parseToolCalls()           // 工具调用解析
 ├─ executeTools()             // skill scripts
 └─ loop
```

**关键差异**：Claude Code有完整的streaming响应+14步消息正规化+并发工具执行，OpenClaw目前是顺序执行。

---

## 工具系统对比

### Claude Code — 36个内置工具

| 类别 | 工具 |
|------|------|
| 文件操作 | Read/Write/Edit/BatchEdit/Glob/Grep |
| Shell | Bash/Cd/Ls/Shell |
| Web | WebFetch/WebSearch/WebBrowse |
| Git | GitBranch/GitCommit/GitDiff/GitPush... |
| 开发 | Submit/Diff/NotebookEdit/LSP... |
| 搜索 | TodoWrite/TodoRead/Notebook... |
| MCP | MCPTool... |

### 工具执行管道（10层）

```
parseToolCalls → resolveServers → loadDeferred → applyPreHooks
  → checkPermissions → resolveArguments → executeAll [并发]
  → collectResults → applyResultHooks → appendAndContinue
```

### OpenClaw — Skill系统

| 类别 | 技能 |
|------|------|
| 核心 | evolver, proactive-agent, self-improving-agent |
| 系统 | system-controller, windows-control, windows-ui-automation |
| 文档 | word-docx, excel-xlsx, ppt-generator |
| 通信 | wechat-qq-sender, agent-browser |
| 记忆 | agent-memory, memory-tiering, memory-system-v2 |
| 工具 | github, gog, image, summarize |

**关键差异**：
- Claude Code 工具在源码内硬编码，OpenClaw 用 skill 脚本外置
- Claude Code 有并发工具执行，OpenClaw 顺序执行
- Claude Code 有 pre/post tool hooks，OpenClaw 无此机制

---

## 权限安全对比（重点）

### Claude Code — 7层纵深防御

| Layer | 机制 | 说明 |
|-------|------|------|
| 1 | AI Policy | System prompt约束 |
| 2 | Tree-sitter AST | 结构性解析，过复杂→ask |
| 3 | 23个Bash验证器 | 注入攻击/混淆/解析差异 |
| 4 | Permission Rules | 4行为×3匹配×8来源 |
| 5 | Path Constraints | 白名单+危险路径+symlink解析 |
| 6 | Read-Only Validation | 命令白名单+flag级控制 |
| 7 | OS Sandbox | bwrap/sandbox-exec |

### 23个Bash验证器（关键）

**Misparsing攻击（7个）**：shell-quote与实际bash行为差异
- CARRIAGE_RETURN, BACKSLASH_WHITESPACE, BRACE_EXPANSION, UNICODE_WHITESPACE, BACKSLASH_OPERATORS, COMMENT_QUOTE_DESYNC, QUOTED_NEWLINE

**注入模式（8个）**：INCOMPLETE_COMMANDS, DANGEROUS_VARIABLES, DANGEROUS_PATTERNS, IFS_INJECTION, PROC_ENVIRON, REDIRECTIONS, OBFUSCATED_FLAGS

**混淆检测（8个）**：ANSI-C quotes, quoted flags, Unicode whitespace

### OpenClaw — 当前权限

- Windows API：无内置安全层，依赖系统权限
- Bash执行：通过 PowerShell 包装，有基础参数校验
- 文件操作：无路径约束机制
- **差距巨大**：Claude Code有7层，OpenClaw几乎没有

---

## 记忆系统对比（重点）

### Claude Code — 6个子系统

| 子系统 | 触发 | 存储 | 目的 |
|--------|------|------|------|
| Auto Memory | Session开始 | `~/.claude/projects/{proj}/memory/` | 跨session永久记忆 |
| ExtractMemories | 每次query后 | 同上 | 后台自动萃取 |
| Session Memory | Context达阈值 | `~/.claude/session-memory/{id}.md` | 当前session快照 |
| MagicDocs | 对话闲时 | repo内`.md`文件 | 自动维护文档 |
| Team Memory | Session开始/file changes | `memory/team/` | 跨用户共享记忆 |
| AutoDream | 24h+5 sessions | 整合至MEMORY.md | 跨session记忆整合 |

### 4种记忆类型
- `user`: 用户角色、目标、知识背景
- `feedback`: 纠正原则、成功确认
- `project`: 项目目标、决策、事件
- `reference`: 外部系统参考

### OpenClaw — 当前记忆

| 子系统 | 状态 |
|--------|------|
| MEMORY.md | ✅ 长期记忆，手动更新 |
| memory/YYYY-MM-DD.md | ✅ 每日日记，事件驱动 |
| agent-memory (SQLite) | ✅ 刚激活，6 facts |
| HOT/WARM/COLD三层 | ✅ 刚部署 |
| Ontology知识图谱 | ✅ 刚初始化 |
| SESSION-STATE.md | ✅ WAL目标，活跃工作 |

**差距**：
- Claude Code有6个自动子系统，OpenClaw大部分是手动
- Claude Code有AutoDream（睡眠时计算），OpenClaw无
- Claude Code有MEMORY.md索引设计，OpenClaw直接存内容

---

## Context管理对比

### Claude Code — 5个阈值常数

| 名称 | 值 | 用途 |
|------|-----|------|
| Autocompact margin | effective - 13,000 | 触发压缩 |
| Warning threshold | autocompact + 20,000 | 黄色UI |
| Error threshold | warning + 20,000 | 红色UI |
| Hard blocking limit | 距绝对墙3,000 | Session冻结 |
| Circuit breaker | 3次连续失败 | 停止尝试 |

### 9个必须摘要Section

1. Primary Request and Intent
2. Key Technical Concepts
3. Files and Code Sections（含完整snippets）
4. Errors and Fixes
5. Problem Solving
6. All user messages（每条非工具结果的用户消息）
7. Pending Tasks
8. Current Work（最重要）
9. Optional Next Step（必须逐字引用最新对话）

### OpenClaw — 当前Context管理

- 无自动compact机制
- 无多级警告阈值
- 无session冻结保护
- 无压缩失败circuit breaker

**差距巨大**：Claude Code有完整上下文生命周期管理，OpenClaw基本没有。

---

## Feature Flags系统

### Claude Code — 87个Feature Flags

```
tengu_前缀 + 随机词对 = 混淆命名
tengu_passport_quail  → 记忆提取门控
tengu_moth_copse     → 记忆提取启用
tengu_kairos         → KAIROS自主模式
tengu_amber_json_tools → JSON工具格式
```

### OpenClaw — 当前Feature Flags

- evolver: `EVOLVE_STRATEGY=balanced`
- openclaw: 无Feature Flag系统
- 插件: 各有独立config

**借鉴价值**：tengu混淆命名值得学习，阻止源码泄露后功能推断。

---

## Subagent对比

### Claude Code

| 类型 | 工具集 | 用途 |
|------|--------|------|
| general-purpose | 全部 | 复杂多步骤任务 |
| Explore | 只读 | 代码库探索 |
| Plan | 只读 | 设计实现方案 |
| 60+内置代理 | 按定义 | 专业领域任务 |

**关键**：共享父上下文，独立权限状态，支持嵌套（一般不超过2层）

### OpenClaw

- `isolated agentTurn`: 隔离session
- `systemEvent`: 主session内system事件
- 无嵌套子agent
- 无父上下文共享机制

---

## Compact机制

### Claude Code

- **3种模式**：BASE / PARTIAL FROM / PARTIAL UP_TO
- **9个必须Section**：详见上文
- **`<analysis>`沙箱**：模型先写草稿推理，不进入后续context
- **触发后自动重触发**：压缩后token仍超阈值则下一turn继续

### OpenClaw

- 无compact机制
- 无context压缩
- 无摘要生成能力

---

## Prompt Cache对比

### Claude Code

- **Sticky Latch**：4种自锁模式，一旦启用永不关闭
- **Cache Break检测**：12个原因分类
- **Daily Cache Wipe**：日期变更=所有缓存失效
- **成本模型**：Cache hit=10%输入价格，miss=125%输入价格

### OpenClaw

- 无Prompt Cache机制
- 每次都是完整context传输

---

## 对OpenClaw最有价值的借鉴

### 立即可实现（高优先级）

1. **Permission分级**：引入4级权限模式（auto/ask/bypass/default）
2. **路径约束**：实现工作目录白名单+危险路径保护
3. **Compact机制**：当context>60%时触发摘要生成
4. **消息正规化**：14步管道标准化输入

### 中期实现

5. **记忆子系统**：建立ExtractMemories后台自动萃取
6. **Pre/Post Tool Hooks**：工具执行前后置拦截器
7. **Subagent上下文共享**：isolated agentTurn支持父上下文访问
8. **Bash验证器**：实现23个安全验证器（或简化版）

### 长期研究

9. **Feature Flag系统**：tengu混淆命名
10. **AutoDream**：Sleep-time Compute记忆整合
11. **OS Sandbox**：bwrap/sandbox-exec隔离
12. **Prompt Cache**：成本优化

---

## 总结评分

| 维度 | Claude Code | OpenClaw | 差距 |
|------|------------|-----------|------|
| 安全 | 9/10 | 2/10 | 巨大 |
| 记忆 | 8/10 | 4/10 | 大 |
| 上下文管理 | 9/10 | 2/10 | 巨大 |
| 工具系统 | 8/10 | 5/10 | 中 |
| Subagent | 8/10 | 3/10 | 大 |
| 流式响应 | 10/10 | 1/10 | 巨大 |
| Feature Flags | 7/10 | 0/10 | 极大 |
