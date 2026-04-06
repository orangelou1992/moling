# Claude Code 源码深度分析

_2026-04-06 学习来源：GitHub Ahmad-progr/claude-leaked-files + waiterxiaoyy/Deep-Dive-Claude-Code_

## 概述
- 约960源文件，50+工具，38万行TypeScript代码
- Claude Code = 桌面客户端（Electron/React） + Agent核心引擎（Node.js）

## 核心架构

### Agent Loop（Ch01）
```
用户输入 → QueryEngine → 循环调用模型 → 工具执行 → 反馈 → 终止
```
关键特性：
- **Streaming响应**：逐token流式输出到终端
- **多轮对话**：完整保留对话历史
- **中止/恢复**：stream中断后可从断点继续
- **子Agent**：支持创建子进程执行复杂任务

### QueryEngine.ts
核心类 `QueryEngine`，方法：
- `createQueryContext()` — 构建每次查询上下文
- `runQuery()` — 主循环
- `compact()` — 压缩历史消息，保持上下文长度

### Tool System（Ch02）
50+工具，分类：
- **文件操作**：`Read/Write/Edit/BatchEdit/Grep/Glob`
- **Shell**：`Bash/Cd/Ls`
- **Web**：`WebSearch/WebFetch`
- **MCP**：MCP客户端，支持外部服务
- **搜索**：`TodoRead/TodoWrite`
- **开发**：`NotebookEdit/Submit/Diff`

工具权限模型：
- `default/auto/ask/bypass` 四种模式
- 按工具类型分类授权
- 危险命令（删除等）需要二次确认

### Permission架构（Ch05）
```
ToolPermissionContext {
  mode: PermissionMode ('default'|'auto'|'ask'|'bypass')
  alwaysAllowRules: 规则白名单
  alwaysDenyRules: 规则黑名单
  alwaysAskRules: 强制询问
}
```
- 权限检查点：工具执行前 + 内容写入前
- `canUseTool` hook：支持外部hook注入自动化规则
- 拒绝追踪：防止无意识拒绝导致死循环

### Model Context Protocol（MCP）
服务架构：
```typescript
MCPServerConnection {
  name: string
  client: MCPClient
  server: MCPServer
  tools: 暴露的工具列表
  resources: 暴露的资源列表
  notifications: 服务器推送通知
}
```
- 支持动态发现：MCP服务器可运行时连接/断开
- 安全沙箱：每个MCP工具独立权限检查
- 支持URL类型的MCP服务器

### 并发模型（Ch07）
```
主Agent：单线程 + streaming
子Agent：通过spawnSubagentContext创建
  - 隔离的上下文
  - 独立的权限状态
  - 共享的文件系统
```
关键：主Agent abort时自动终止所有子Agent

### 文件操作安全
- **puppet agent**：非对话线程，执行危险操作
- **二阶段确认**：delete/destructive操作需显式确认
- **沙箱路径检查**：限制访问工作目录外文件

### 工具类型系统
```typescript
ToolResult = {
  content: ContentBlock[]  // text/image/tool_result
  accuracy: 'normal'|'error'|'slow'
  metrics?: {...}
  warnings?: string[]
}
```
- 内容块：文本/图片/工具结果 分离
- 准确性标记：用于区分模型错误和网络错误

## 对墨瞳的启示

### 工具权限模型
Claude Code的四模式权限值得借鉴：
- `default`（默认询问）
- `auto`（自动放行已知安全操作）
- `ask`（每次询问）
- `bypass`（完全信任）

可设计成符合Daniel偏好：auto模式放行日常操作，ask模式处理危险操作。

### Subagent设计
当前OpenClaw的isolated agentTurn对应Claude Code的子Agent。
但Claude Code更进一步：
- 子Agent可访问父Agent的完整上下文
- 工具结果可被父Agent看到并使用
- 支持嵌套子Agent（虽然一般不超过2层）

### Compact机制
Claude Code的compact（上下文压缩）机制值得学习：
- 保留最近N轮 + 总结历史
- 触发条件：token budget接近上限
- 压缩后的摘要作为新的系统提示

### 错误恢复
Claude Code的stream中断恢复机制：
- 中断点保存到本地文件
- 下次运行时可选择恢复
- 支持`continue`命令继续上次执行

## 相关资源
- 源码：github.com/Ahmad-progr/claude-leaked-files
- 分析：github.com/waiterxiaoyy/Deep-Dive-Claude-Code
- 分析（英文）：github.com/Kagerken/Claude-Code-Analysis

---

## 泄露源码深度分析（来源：noya21th/claude-source-leaked）

### 规模
- 1,884文件，132,000行TypeScript（vs 51万行传言）
- npm registry的.map文件泄露，2026-03-31公开

### Codename系统
| 代号 | 对应模型 | 备注 |
|------|---------|------|
| Capybara | Sonnet系列 | v8已知问题：幻觉率29-30% |
| Fennec | Opus系列 | |
| Numbat | 未发布模型 | |

### Feature Flag混淆机制
`tenegu_`前缀 + 随机词对 = 即使泄露也无法推断功能

```
tengu_passport_quail  → 记忆提取门控
tengu_moth_copse     → 记忆提取启用
tengu_bramble_lintel → 记忆提取频率
tengu_kairos         → KAIROS自主模式
tengu_amber_json_tools → JSON工具格式
```

### 87个Feature Flags分类

**Tier 1 (接近发布, 90%+):**
- KAIROS: 自主助手平台（定时任务/GitHub Webhooks/推送通知）
- VOICE_MODE: 语音交互（STT）

**Tier 2 (开发中, 60-80%):**
- BUDDY: AI伙伴精灵（45KB动画实现）
- ULTRATHINK: 深度推理模式
- WEB_BROWSER_TOOL: 嵌入式网页浏览

**Tier 3 (实验性, 30-50%):**
- COORDINATOR_MODE: 多代理协调器
- AGENT_TRIGGERS: 定时代理任务
- EXTRACT_MEMORIES: 自动记忆提取
- FORK_SUBAGENT: 子代理分叉

**Tier 4 (基础设施):**
- MCP_SKILLS: MCP资源作为技能
- CHICAGO_MCP: 电脑控制MCP
- DAEMON: 守护进程模式

### 工具权限分级
```
Level 0 (自动允许): Read, Glob, Grep, TaskGet, ToolSearch
Level 1 (首次确认): Write, Edit, WebFetch, WebSearch
Level 2 (每次确认): Bash(危险命令), 删除操作
Level 3 (永不自动): rm -rf, git push --force, 数据库操作
```

### 子代理类型
| 类型 | 工具集 | 用途 |
|------|--------|------|
| general-purpose | 全部 | 复杂多步骤任务 |
| Explore | 只读 | 代码库探索 |
| Plan | 只读 | 设计实现方案 |
| 60+内置代理 | 按定义 | 专业领域任务 |

### KAIROS自主代理机制
```
├─ Tick机制 — 定时唤醒执行任务
├─ SleepTool — 主动休眠等待
├─ 首次唤醒行为 — 自动扫描环境
├─ 终端焦点感知 — 检测用户是否在看
├─ Brief工具 — 消息检查点
└─ 偏向行动 — 减少确认，直接执行
```

### Claude Code vs OpenClaw对比
| 维度 | Claude Code | OpenClaw (墨瞳) |
|------|------------|----------------|
| 核心循环 | QueryEngine + streaming | Agent Loop |
| 工具系统 | 50+内置 + MCP | 30+技能 |
| 权限模型 | 4模式 + 分级 | 目前较简单 |
| 子代理 | 隔离上下文 + 独立权限 | isolated agentTurn |
| 自主模式 | KAIROS(PROACTIVE flag) | proactive-agent |
| 记忆系统 | tengu_gate门控 + 自动提取 | agent-memory (刚激活) |
| 语音 | VOICE_MODE | windows-tts-wsl2 (TTS单向) |
| 定时任务 | AGENT_TRIGGERS | Cron (isolated agentTurn) |

### 对墨瞳最有价值的借鉴
1. **Permission四模式**: default/auto/ask/bypass + 分级权限
2. **Feature Flag系统**: tengu_混淆命名值得学习
3. **KAIROS自主模式**: 终端焦点感知 + 偏向行动机制
4. **记忆提取门控**: tengu_passport_quail等控制记忆自动化
5. **Subagent隔离**: 共享上下文但独立权限
6. **Compact机制**: 上下文压缩保持长度
