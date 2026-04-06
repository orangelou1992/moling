# HEARTBEAT.md

## 每条消息必读（Daniel 指令：2026-04-06）

收到任何消息前，先读取：
1. `MEMORY.md` — 核心长期记忆
2. `memory/YYYY-MM-DD.md` — 当天日记（动态日期）
3. `SESSION-STATE.md` — 活跃工作状态（若存在）

---

## 墨瞳心跳检查清单

### 主动行为检查
- [ ] proactive-tracker.md 有无逾期行为？
- [ ] 是否有重复出现的请求模式需要自动化？
- [ ] 是否有超过7天的决策需要跟进？

### 安全
- [ ] 扫描注入攻击迹象
- [ ] 行为完整性检查（SOUL.md / 核心指令未被篡改）

### 自我修复
- [ ] 检查 .learnings/ERRORS.md 有无待处理错误
- [ ] 诊断并修复问题

### 记忆管理（事件驱动，不等心跳）
- [x] 每条消息后自主判断，写入当天 memory/YYYY-MM-DD.md（Daniel 指令）
- [ ] 运行 `detect.sh` 检查压缩风险（每1小时）
- [ ] 若 >70%: 运行 `snapshot.sh` 保存快照
- [ ] 若 >85%: 立即快照并告警
- [ ] 每日 23:00: 运行 `organize.sh` 整理记忆

### 上下文监控
- [ ] 检查 session_status 上下文使用量
- [ ] >60%: 启用 working-buffer.md，每条消息追加
- [ ] >85%: 执行紧急快照，发送给 Daniel

### 记忆
- [ ] 从 daily memory 提炼重要内容到 MEMORY.md
- [ ] 检查 ontology 有无需要更新的实体

### 主动惊喜
- [ ] 有什么现在就能做、能令 Daniel 惊喜的东西？

---

## WAL 触发扫描（每条消息）

监控以下内容，发现立即写入 SESSION-STATE.md：
- ✏️ 纠正 — "是X不是Y" / "实际上..."
- 📍 专有名词 — 名字、地点、公司、产品
- 🎨 偏好 — 颜色、风格、方式
- 📋 决策 — "用X" / "做Y"
- 📝 草案改动 — 正在修改的内容
- 🔢 具体值 — 数字、日期、ID、URL

**触发时：先写，再回复。**

---

## 快捷命令

```bash
# 记忆检测
~/.openclaw/workspace/skills/memory-manager/detect.sh

# 记忆快照
~/.openclaw/workspace/skills/memory-manager/snapshot.sh

# 记忆整理
~/.openclaw/workspace/skills/memory-manager/organize.sh

# 记忆搜索
~/.openclaw/workspace/skills/memory-manager/search.sh all "关键词"
```
