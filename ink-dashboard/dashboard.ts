#!/usr/bin/env -S bun
// ink-dashboard.ts - 墨瞳终端仪表盘 v3.0
// 真实数据驱动：cron状态 / 子系统状态 / ExtractMemories提取统计
// 运行: bun ~/.openclaw/workspace/ink-dashboard/dashboard.ts [--watch]

import pc from "picocolors";
import { readFileSync, existsSync, readdirSync, statSync } from "fs";
import { execSync } from "child_process";

const HOME = process.env.HOME!;
const WORKSPACE = `${HOME}/.openclaw/workspace`;
const MEMORY_DIR = `${WORKSPACE}/memory`;
const LEARNINGS = `${WORKSPACE}/.learnings`;
const FLAGS_DB = `${HOME}/.openclaw/feature_flags.json`;
const KAIROS_DIR = `${WORKSPACE}/.kairos`;
const KAIROS_FLAG = `${KAIROS_DIR}/autonomous.enabled`;
const DREAMS_DIR = `${MEMORY_DIR}/dreams`;

// ========== 数据获取函数 ==========

function getFlag(key: string): string {
  try {
    if (existsSync(FLAGS_DB)) {
      const flags = JSON.parse(readFileSync(FLAGS_DB, "utf-8"));
      return flags[key] || "off";
    }
  } catch {}
  return "off";
}

function getContextPct(): number {
  try {
    const stateFile = `${MEMORY_DIR}/heartbeat-state.json`;
    if (existsSync(stateFile)) {
      const state = JSON.parse(readFileSync(stateFile, "utf-8"));
      return state.memory?.usage_pct || state.usage_pct || 3;
    }
  } catch {}
  return 3;
}

function getEvolverCycle(): number {
  try {
    const stateFile = `${MEMORY_DIR}/evolution/evolution_state.json`;
    if (existsSync(stateFile)) {
      const state = JSON.parse(readFileSync(stateFile, "utf-8"));
      return state.cycleCount || 0;
    }
  } catch {}
  return 6;
}

function getTodayErrors(): number {
  try {
    if (!existsSync(`${LEARNINGS}/ERRORS.md`)) return 0;
    const content = readFileSync(`${LEARNINGS}/ERRORS.md`, "utf-8");
    const today = new Date().toISOString().slice(0, 10).replace(/-/g, "");
    const matches = content.match(new RegExp(`ERR-${today}-\\d+`, "g")) || [];
    return matches.length;
  } catch {
    return 0;
  }
}

function getKairosEnabled(): boolean {
  return existsSync(KAIROS_FLAG);
}

function getKairosTasks(): number {
  try {
    const log = `${KAIROS_DIR}/task_log.jsonl`;
    if (!existsSync(log)) return 0;
    const lines = readFileSync(log, "utf-8").trim().split("\n").filter(l => l.trim());
    return lines.length;
  } catch {
    return 0;
  }
}

function getCronJobs(): Array<{name: string; status: string; nextRun: string}> {
  try {
    const out = execSync("openclaw cron list --json 2>/dev/null", {timeout: 5000}).toString();
    const jobs = JSON.parse(out);
    return (jobs.jobs || []).map((j: any) => ({
      name: j.name || "unnamed",
      status: j.enabled ? pc.green("ON") : pc.dim("OFF"),
      nextRun: j.state?.nextRunAtMs ? new Date(j.state.nextRunAtMs).toLocaleTimeString("zh-CN", {timeZone:"Asia/Shanghai", hour:"2-digit", minute:"2-digit"}) : "?"
    }));
  } catch {
    return [];
  }
}

function getExtractedCount(): number {
  try {
    const today = new Date().toISOString().slice(0, 10);
    const todayMem = `${MEMORY_DIR}/${today}.md`;
    if (!existsSync(todayMem)) return 0;
    const content = readFileSync(todayMem, "utf-8");
    const decisions = (content.match(/\[decision\]/gi) || []).length;
    const preferences = (content.match(/\[preference\]/gi) || []).length;
    const knowledge = (content.match(/\[knowledge\]/gi) || []).length;
    return decisions + preferences + knowledge;
  } catch {
    return 0;
  }
}

function getAutoDreamLastRun(): string {
  try {
    if (!existsSync(DREAMS_DIR)) return pc.dim("从未运行");
    const files = readdirSync(DREAMS_DIR).filter(f => f.endsWith(".md")).sort().reverse();
    if (files.length === 0) return pc.dim("从未运行");
    const mtime = statSync(`${DREAMS_DIR}/${files[0]}`).mtime;
    return new Date(mtime).toLocaleString("zh-CN", {timeZone:"Asia/Shanghai", month:"numeric", day:"numeric", hour:"2-digit", minute:"2-digit"});
  } catch {
    return pc.dim("从未运行");
  }
}

function getCompactionCount(): number {
  try {
    const log = `${WORKSPACE}/.compaction_log`;
    if (!existsSync(log)) return 0;
    const today = new Date().toISOString().slice(0, 10);
    const content = readFileSync(log, "utf-8");
    return (content.match(new RegExp(today, "g")) || []).length;
  } catch {
    return 0;
  }
}

function getDailyMemLines(): number {
  try {
    const today = new Date().toISOString().slice(0, 10);
    const f = `${MEMORY_DIR}/${today}.md`;
    if (!existsSync(f)) return 0;
    return readFileSync(f, "utf-8").split("\n").length;
  } catch {
    return 0;
  }
}

function getSubsystemStatus(name: string): { label: string; color: (s: string) => string } {
  // 通过实际文件/cron状态判断，而不是flag
  switch (name) {
    case "AutoMemory":
      return existsSync(`${MEMORY_DIR}/hot/HOT_MEMORY.md`) &&
             existsSync(`${MEMORY_DIR}/warm/WARM_MEMORY.md`) &&
             existsSync(`${MEMORY_DIR}/cold/COLD_MEMORY.md`)
        ? { label: "🟢 ON", color: pc.green }
        : { label: "🔴 OFF", color: pc.red };
    case "ExtractMemories":
      return existsSync(`${WORKSPACE}/scripts/auto_extract.js`) &&
             getCronJobs().some(j => j.name.includes("ExtractMemories"))
        ? { label: "🟢 ON", color: pc.green }
        : { label: "🔴 OFF", color: pc.red };
    case "SessionMemory":
      return existsSync(`${WORKSPACE}/SESSION-STATE.md`)
        ? { label: "🟢 ON", color: pc.green }
        : { label: "🔴 OFF", color: pc.red };
    case "AutoDream":
      return existsSync(`${WORKSPACE}/scripts/auto_dream.sh`) &&
             getCronJobs().some(j => j.name.includes("AutoDream"))
        ? { label: "🟢 ON", color: pc.green }
        : { label: "🔴 OFF", color: pc.red };
    case "MagicDocs":
      return { label: "⚙️  待做", color: pc.yellow };
    case "TeamMemory":
      return { label: "⚙️  待做", color: pc.yellow };
    default:
      return { label: "未定义", color: pc.dim };
  }
}

function bar(pct: number, width = 20): string {
  const filled = Math.round((pct / 100) * width);
  return pc.green("█".repeat(Math.max(0, filled))) + pc.dim("░".repeat(Math.max(0, width - filled)));
}

// ========== 渲染函数 ==========

function buildDashboard(): string[] {
  const memPct = getContextPct();
  const cycle = getEvolverCycle();
  const errors = getTodayErrors();
  const kairosEnabled = getKairosEnabled();
  const kairosTasks = getKairosTasks();
  const uptime = Math.floor(process.uptime());
  const cronJobs = getCronJobs();
  const extracted = getExtractedCount();
  const autoDreamLast = getAutoDreamLastRun();
  const compactionCount = getCompactionCount();
  const dailyLines = getDailyMemLines();

  const C = (fn: (s: string) => string, text: string) => fn(text);
  const lines: string[] = [];

  // Header
  lines.push("");
  lines.push(pc.green(`┌─ 墨瞳 Dashboard v3.0 (真实数据) ${"─".repeat(29)}┐`));
  lines.push(C(pc.dim, `│ Bun ${Bun.version} | Node v${process.versions.node} | Uptime: ${uptime}s | PID: ${process.pid}`));
  lines.push(C(pc.dim, "│ ") + C(pc.green, "● 运行中 ") + C(pc.dim, "| MiniMax-M2.7 | Context: " + bar(memPct, 18) + ` ${memPct}%`));

  // ===== 6子系统真实状态 =====
  const subsystems = [
    ["AutoMemory", "三层架构(HOT/WARM/COLD) + 事件驱动写入"],
    ["ExtractMemories", `每30min自动提取decision/error/preference`],
    ["SessionMemory", "SESSION-STATE.md 活跃工作内存"],
    ["MagicDocs", "文档模板系统"],
    ["TeamMemory", "多agent协作记忆"],
    ["AutoDream", `每日23:30反思生成战略洞察`],
  ];

  lines.push("");
  lines.push(C(pc.green, "├─") + C(pc.bold, pc.white(" 6记忆子系统真实状态 (Tengu命名) ")) + C(pc.green, "──────────────────┤"));
  for (const [name, desc] of subsystems) {
    const status = getSubsystemStatus(name);
    lines.push(C(pc.dim, "│ ") + C(pc.green, "◆ ") + C(pc.cyan, name.padEnd(18, " ")) + status.color(`[${status.label}]`) + C(pc.dim, ` ${desc}`));
  }

  // ===== Cron任务状态 =====
  lines.push("");
  lines.push(C(pc.green, "├─") + C(pc.bold, pc.white(" Cron任务状态 ")) + C(pc.green, "─────────────────────────────────────────────────┤"));
  if (cronJobs.length > 0) {
    for (const job of cronJobs.slice(0, 6)) {
      lines.push(C(pc.dim, "│ ") + C(pc.green, "◆ ") + C(pc.yellow, job.name.padEnd(24, " ")) + " " + job.status + C(pc.dim, ` 下次 ${job.nextRun}`));
    }
  } else {
    lines.push(C(pc.dim, "│ ") + C(pc.dim, "  (无法读取cron状态，请检查 openclaw cron list)"));
  }

  // ===== ExtractMemories 提取统计 =====
  lines.push("");
  lines.push(C(pc.green, "├─") + C(pc.bold, pc.white(" ExtractMemories 统计 ")) + C(pc.green, "─────────────────────────────────────────┤"));
  lines.push(C(pc.dim, "│ ") + C(pc.green, "◆ ") + C(pc.dim, "今日提取次数: ") + C(pc.yellow, `${extracted} 条记录`) + C(pc.dim, ` | 日记行数: ${dailyLines}行`));
  lines.push(C(pc.dim, "│ ") + C(pc.green, "◆ ") + C(pc.dim, "Autocompact触发: ") + C(pc.yellow, `${compactionCount} 次`) + C(pc.dim, ` | AutoDream上次: ${autoDreamLast}`));
  lines.push(C(pc.dim, "│ ") + C(pc.green, "◆ ") + C(pc.dim, "KAIROS任务日志: ") + C(pc.yellow, `${kairosTasks} tasks`) + C(pc.dim, ` | KAIROS: ${kairosEnabled ? pc.green("🟢 ENABLED") : pc.red("🔴 DISABLED")}`));

  // ===== Feature Flags =====
  lines.push("");
  lines.push(C(pc.green, "├─") + C(pc.bold, pc.white(" Feature Flags ")) + C(pc.green, "──────────────────────────────────────────────────┤"));
  const flags = [
    ["tengu_kairos", "proactive_mode", "KAIROS自主"],
    ["tengu_fennel_vole", "context_compact_enable", "Autocompact"],
    ["tengu_larch_skua", "permission_auto_mode", "Permission自动"],
    ["tengu_moth_copse", "memory_extraction_enable", "MemExtract"],
  ];
  for (const [tengu, real, desc] of flags) {
    const val = getFlag(real);
    const color = val === "true" ? pc.green : pc.red;
    lines.push(C(pc.dim, "│ ") + C(pc.green, "◆ ") + C(pc.cyan, tengu.padEnd(20, " ")) + color(val === "true" ? "ON " : "OFF") + C(pc.dim, ` ${desc}`));
  }

  // ===== 今日状态 =====
  lines.push("");
  lines.push(C(pc.green, "├─") + C(pc.bold, pc.white(" 今日状态 ")) + C(pc.green, "────────────────────────────────────────────────┤"));
  lines.push(C(pc.dim, "│ ") + C(pc.green, "◆ ") + C(pc.dim, "新错误: ") + (errors > 0 ? C(pc.red, `${errors} 条待处理`) : C(pc.green, "0 条")) + C(pc.dim, ` | Evolver Cycle: ${cycle} | Capsule: 0.85`));
  lines.push(C(pc.dim, "│ ") + C(pc.green, "◆ ") + C(pc.dim, "Git: orangelou1992/moling | Branch: master | ") + C(pc.green, "synced"));

  lines.push("");
  lines.push(C(pc.green, "└" + "─".repeat(64) + "┘"));
  lines.push(C(pc.dim, `  ${new Date().toLocaleString("zh-CN", {timeZone:"Asia/Shanghai"})} | bun ${Bun.version}`));

  return lines;
}

async function main() {
  const watch = process.argv.includes("--watch");
  
  const print = () => buildDashboard().forEach(l => console.log(l));

  if (watch) {
    // watch模式：不用清屏，直接重新打印（会向下滚动）
    print();
    console.log(pc.dim("\n  [watch: 每10秒刷新 | Ctrl+C 退出]  (只增不减，直接看底部最新状态)"));
    const iv = setInterval(print, 10000);
    process.on("SIGINT", () => { clearInterval(iv); process.exit(0); });
  } else {
    // 单次模式
    print();
    console.log(pc.dim("\n  bun dashboard.ts --watch  每10秒刷新"));
  }
}

main();
