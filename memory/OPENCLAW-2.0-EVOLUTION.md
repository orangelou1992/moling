# OpenClaw 2.0 进化计划

_基于 Claude Code 泄露源码分析_
_2026-04-06_

---

## 目标

从 OpenClaw 1.0（当前）→ OpenClaw 2.0（Claude Code架构级别）

---

## 需要进化的模块

### 1. 运行时：Node.js → Bun ✅ 已安装
- 状态：Bun 1.3.11 已安装
- 目标：技能脚本迁移到 Bun
- 依赖：Daniel 需要帮助迁移 Gateway

### 2. 工具执行管道
**现状**：顺序执行，无hooks
**目标**：10层管道
```
parseToolCalls → resolveServers → loadDeferred → applyPreHooks
  → checkPermissions → resolveArgs → executeAll (并发)
  → collectResults → applyResultHooks → append
```
**实施**：
- [ ] 编写 tool-execution-pipeline.js
- [ ] 实现 pre/post tool hooks
- [ ] 实现并发执行（Promise.all）
- [ ] 集成 permission_check.sh

### 3. Permission系统
**现状**：无分级
**目标**：4级权限
```
L0: auto        → read类操作
L1: first-confirm → write类操作
L2: always-confirm → dangerous操作
L3: never-auto   → rm -rf等
```
**实施**：
- [x] tool_validator.sh ✅
- [x] permission_check.sh ✅
- [ ] 集成到工具执行管道
- [ ] 实现23个Bash验证器（简化版）

### 4. Context管理
**现状**：无compact，无阈值
**目标**：5阈值 + 9段摘要
```
Autocompact margin: effective - 13,000 tokens
Warning threshold:  +20,000
Error threshold:    +20,000  
Circuit breaker:    3次连续失败
Hard blocking:      距绝对墙3,000
```
**9个必须摘要Section**：
1. Primary Request and Intent
2. Key Technical Concepts
3. Files and Code Sections（含完整snippets）
4. Errors and Fixes
5. Problem Solving
6. All user messages
7. Pending Tasks
8. Current Work（最重要）
9. Optional Next Step
**实施**：
- [x] compact_context.sh ✅
- [ ] 实现 compact_agent.js
- [ ] 实现 context threshold monitoring
- [ ] 实现 circuit breaker

### 5. 记忆系统
**现状**：手动，6 facts
**目标**：6子系统自动萃取
```
Auto Memory → ExtractMemories → SessionMemory
→ MagicDocs → TeamMemory → AutoDream
```
**实施**：
- [ ] ExtractMemories hook（每次响应后自动萃取）
- [ ] SessionMemory（context达阈值时快照）
- [ ] AutoDream（sleep-time计算）
- [ ] memory/CLAUDE-STYLE/ 目录结构

### 6. Feature Flag系统
**现状**：无
**目标**：Tengu混淆命名
```
tengu_passport_quail  → 记忆提取门控
tengu_moth_copse     → 记忆提取启用
tengu_kairos         → 自主模式
```
**实施**：
- [ ] feature_flags.json 配置
- [ ] 混淆解码逻辑
- [ ] 门控检查函数

### 7. Subagent架构
**现状**：isolated session，隔离
**目标**：共享上下文 + 独立权限
**实施**：
- [ ] agent_pool.js（子agent池）
- [ ] 上下文共享机制
- [ ] 嵌套限制（≤2层）

### 8. 终端UI（长期）
**现状**：无专用UI
**目标**：React+Ink风格CLI
- Claude Code使用Ink（React的Go绑定）
- 需要研究可行性
- 可能需要Daniel帮助构建

### 9. 流式响应（长期）
**现状**：HTTP API，无streaming
**目标**：完整streaming
- OpenClaw Gateway需要改造
- 可能需要Daniel帮助

---

## 进化优先级

### P0（立即可做，无需Daniel帮助）
1. Permission系统集成到工具管道
2. Context压缩机制完善
3. 记忆提取hook实现
4. Feature Flag系统

### P1（需要Daniel帮助）
1. Bun作为Gateway运行时
2. React+Ink终端UI
3. 流式响应支持

### P2（长期研究）
1. OS Sandbox（bwrap/sandbox-exec）
2. Prompt Cache系统
3. 完整10层工具管道

---

## 当前进度

- [x] Bun安装（1.3.11）
- [x] Permission分级（tool_validator.sh, permission_check.sh）
- [x] Context压缩（compact_context.sh）
- [x] evolver git历史建立
- [ ] Permission集成到执行管道
- [ ] ExtractMemories hook
- [ ] Feature Flag系统
- [ ] Context阈值监控
