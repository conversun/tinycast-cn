#!/usr/bin/env node
"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const root = path.resolve(__dirname, "..");
const tablePath = "Tinycast/zh-Hans.lproj/Localizable.strings";
const args = process.argv.slice(2);
if (args.includes("--help")) {
  console.log("Usage: node Scripts/check-localization.js [--extracted <Xcode source Localizable.strings>]");
  console.log("Checks duplicate keys, format arguments, dynamic title coverage and computed Text properties.");
  process.exit(0);
}
if (args.length && (args.length !== 2 || args[0] !== "--extracted")) {
  console.error("Use --help for usage.");
  process.exit(2);
}
function read(relative) {
  return fs.readFileSync(path.resolve(root, relative), "utf8");
}
function plist(file) {
  return JSON.parse(execFileSync("plutil", ["-convert", "json", "-o", "-", path.resolve(root, file)], {
    encoding: "utf8",
  }));
}
const table = plist(tablePath);
const problems = [];
const seen = new Set();
for (const match of read(tablePath).matchAll(/^\s*("(?:[^"\\]|\\.)*")\s*=/gm)) {
  const key = JSON.parse(match[1]);
  if (seen.has(key)) problems.push(`Duplicate key: ${key}`);
  seen.add(key);
}
function formats(value) {
  const result = [];
  let next = 1;
  for (const match of value.matchAll(/%%|%(?:(\d+)\$)?[-+#0 ]*(?:\d+)?(?:\.\d+)?(lld|llu|ld|lu|zd|zu|@|d|u|f|g|s)/g)) {
    if (match[0] === "%%") continue;
    result.push(`${match[1] ?? next++}:${match[2]}`);
  }
  return result.sort().join(",");
}
for (const [key, value] of Object.entries(table)) {
  if (key && !value) problems.push(`Empty translation: ${key}`);
  if (formats(key) !== formats(value)) problems.push(`Format arguments differ: ${key}`);
}
function requireKey(key, source) {
  if (key && !Object.hasOwn(table, key)) problems.push(`${source}: missing “${key}”`);
}
const catalogs = [
  "Tinycast/Features/Settings/EscapeKeyBehavior.swift",
  "Tinycast/Features/Settings/AppAppearance.swift",
  "Tinycast/Features/Settings/SettingsTab.swift",
  "Tinycast/Features/Settings/InterfaceSize.swift",
  "Tinycast/Features/WindowManagement/Model/WindowLayoutAnchor.swift",
  "Tinycast/Features/Launcher/Model/CommandID.swift",
];
for (const file of catalogs) {
  for (const match of read(file).matchAll(/case\s+[^\n]+:\s*(?:return\s+)?"([^"\\]*)"/g)) {
    const key = match[1];
    if (!/[A-Z]/.test(key) || key.includes(":")) continue;
    requireKey(key, file);
  }
}
for (const file of [
  "Tinycast/Features/Settings/SettingsAnchor.swift",
  "Tinycast/Features/Backup/Model/BackupCategory.swift",
]) {
  for (const match of read(file).matchAll(/(?:title|label|countNoun):\s*"([^"\\]+)"/g)) {
    requireKey(match[1], file);
  }
}
function swiftFiles(folder) {
  return fs.readdirSync(folder, { withFileTypes: true }).flatMap((entry) => {
    const file = path.join(folder, entry.name);
    if (entry.isDirectory()) return swiftFiles(file);
    return file.endsWith(".swift") && !file.endsWith(".generated.swift") ? [file] : [];
  });
}
let checkedProperties = 0;
for (const file of swiftFiles(path.join(root, "Tinycast"))) {
  const source = fs.readFileSync(file, "utf8");
  for (const declaration of source.matchAll(/\bvar (\w+): String\s*\{/g)) {
    const name = declaration[1];
    if (!new RegExp("Text\\(\\s*" + name + "\\s*\\)").test(source)) continue;
    const begin = declaration.index + declaration[0].length;
    let depth = 1;
    let end = begin;
    while (end < source.length && depth) {
      if (source[end] === "{") depth++;
      if (source[end] === "}") depth--;
      end++;
    }
    const body = source.slice(begin, end - 1);
    checkedProperties++;
    for (const literal of body.matchAll(/(?:return\s+|[?:]\s*)("(?:[^"\\]|\\.)*")/g)) {
      if (literal[1].includes("\\(")) continue;
      if (/localized\s*$/.test(body.slice(0, literal.index))) continue;
      let key;
      try { key = JSON.parse(literal[1]); } catch { continue; }
      const tail = body.slice(literal.index + literal[0].length);
      if (/^\s*\)?\.localizedUI/.test(tail)) continue;
      if (Object.hasOwn(table, key) && table[key] !== key) {
        problems.push(path.relative(root, file) + ": Text(" + name + ") receives untranslated literal “" + key + "”");
      }
    }
  }
}
let extractedCount = 0;
if (args.length) {
  const extracted = plist(args[1]);
  for (const key of Object.keys(extracted)) requireKey(key, args[1]);
  extractedCount = Object.keys(extracted).length;
}
if (problems.length) {
  console.error(problems.map((problem) => `FAIL: ${problem}`).join("\n"));
  process.exit(1);
}
console.log(`Localization checks passed: ${seen.size} keys, ${catalogs.length + 2} catalogs, ${checkedProperties} computed Text properties${extractedCount ? `, ${extractedCount} extracted keys` : ""}.`);
console.log("Dynamic user content and unregistered rendering paths still require native UI inspection.");
