#!/usr/bin/env bun
// auto_extract.js - 自动记忆提取 (Bun版)
// Claude Code的ExtractMemories复刻 - Bun运行时版本

import { readFileSync, writeFileSync, appendFileSync, existsSync } from "fs";
import { execSync } from "child_process";

const MEMORY_DIR = `${process.env.HOME}/.openclaw/workspace/memory`;
const LEARNINGS = `${process.env.HOME}/.openclaw/workspace/.learnings`;
const TODAY = new Date().toISOString().slice(0, 10);
const TODAY_MEM = `${MEMORY_DIR}/${TODAY}.md`;

function extractDecisions(text) {
  const matches = text.match(/(决定|用.*?代替|采用|选择|偏好是|用X|做Y)/gi) || [];
  return [...new Set(matches)].slice(0, 3);
}

function extractErrors(text) {
  const matches = text.match(/(error|failed|denied|rejected|SIGKILL|timeout|exception)/gi) || [];
  return [...new Set(matches)].slice(0, 3);
}

function extractPreferences(text) {
  const matches = text.match(/(Daniel喜欢|Daniel要求|Daniel说|不要|应该|必须)/gi) || [];
  return [...new Set(matches)].slice(0, 3);
}

function extractKnowledge(text) {
  const matches = text.match(/([A-Z][a-z]+){2,}|MCP|CDP|GEP|KAIROS|RAG|Honeycomb|TypeScript/g) || [];
  return [...new Set(matches)].slice(0, 5);
}

function logToMemory(type, content) {
  if (!content || content.length < 5) return;
  
  // 避免重复
  if (existsSync(TODAY_MEM)) {
    const existing = readFileSync(TODAY_MEM, "utf-8");
    if (existing.includes(content)) return;
  }
  
  const entry = `[${new Date().toISOString().slice(0, 16)}] [${type}] ${content}\n`;
  appendFileSync(TODAY_MEM, entry);
  console.log(`AUTO-EXTRACT [${type}]: ${content}`);
}

function logErrorToLearnings(errorText) {
  if (!errorText || errorText.length < 10) return;
  
  const errFile = `${LEARNINGS}/ERRORS.md`;
  if (existsSync(errFile)) {
    if (readFileSync(errFile, "utf-8").includes(errorText)) return;
  }
  
  const ts = new Date().toISOString().slice(0, 10).replace(/-/g, "");
  const entry = `

## [ERR-${ts}-AUTO] 自动检测错误

**Logged**: ${new Date().toISOString()}
**Priority**: medium
**Status**: pending
**Area**: auto_extract

### Summary
${errorText}

### Metadata
- Source: auto_extract.js (Bun)
- Tags: auto-detect

`;
  appendFileSync(errFile, entry);
  console.log(`AUTO-ERROR-LOGGED: ${errorText}`);
}

function main() {
  let inputText = "";
  
  if (process.argv[2] && existsSync(process.argv[2])) {
    inputText = readFileSync(process.argv[2], "utf-8");
  } else {
    // stdin
    inputText = readFileSync("/dev/stdin", "utf-8");
  }
  
  if (!inputText) {
    console.log("Usage: bun run auto_extract.js [log_file]\n   or: some_command | bun run auto_extract.js");
    process.exit(1);
  }
  
  const decisions = extractDecisions(inputText);
  const errors = extractErrors(inputText);
  const preferences = extractPreferences(inputText);
  const knowledge = extractKnowledge(inputText);
  
  decisions.forEach(d => logToMemory("decision", d));
  preferences.forEach(p => logToMemory("preference", p));
  knowledge.forEach(k => logToMemory("knowledge", k));
  
  if (errors.length > 0) {
    logErrorToLearnings(errors.join("; "));
  }
  
  console.log(`\n✅ Bun auto_extract done. (${new Date().toISOString().slice(0, 16)})`);
}

main();
