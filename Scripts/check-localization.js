#!/usr/bin/env node
"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const root = path.resolve(__dirname, "..");
const tablePath = "Tinycast/Resources/Localizable.xcstrings";
const args = process.argv.slice(2);
if (args.includes("--help")) {
  console.log("Usage: node Scripts/check-localization.js [--extracted <Localizable.strings or Localizable.xcstrings>]");
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
const problems = [];
const resources = ["Localizable", "InfoPlist"];
for (const name of resources) {
  const file = `Tinycast/Resources/${name}.xcstrings`;
  const seen = new Set();
  for (const match of read(file).matchAll(/^    ("(?:[^"\\]|\\.)*")\s*:/gm)) {
    const key = JSON.parse(match[1]);
    if (seen.has(key)) problems.push(`${file}: Duplicate key: ${key}`);
    seen.add(key);
  }
  for (const [key, entry] of Object.entries(JSON.parse(read(file)).strings)) {
    const translation = entry.localizations?.["zh-Hans"];
    if (key && translation && /"value"\s*:\s*""/.test(JSON.stringify(translation))) {
      problems.push(`${file}: Empty translation: ${key}`);
    }
  }
  if (fs.existsSync(path.join(root, `Tinycast/zh-Hans.lproj/${name}.strings`))) {
    problems.push(`${name}: obsolete zh-Hans.lproj input duplicates compiled catalog output`);
  }
}
try {
  execFileSync(process.execPath, [path.join(root, "Scripts/check-localizations.js")], { encoding: "utf8", stdio: "pipe" });
} catch (error) {
  if (!(error instanceof Error) || !("status" in error)) throw error;
  problems.push(String(error.stderr));
}
const catalog = JSON.parse(read(tablePath));
const table = Object.fromEntries(Object.entries(catalog.strings).map(([key, entry]) => [
  key, entry.localizations?.["zh-Hans"]?.stringUnit?.value
    ?? entry.localizations?.["zh-Hans"]?.variations?.plural?.other?.stringUnit?.value,
]));
function requireKey(key, source) {
  if (/\p{L}/u.test(key) && !table[key] && catalog.strings[key]?.shouldTranslate !== false) {
    problems.push(`${source}: missing “${key}”`);
  }
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
  for (const match of read(file).matchAll(/case\s+[^\n]+:\s*(?:return\s+)?(?:String\(localized:\s*)?"([^"\\]*)"/g)) {
    const key = match[1];
    if (!/[A-Z]/.test(key) || key.includes(":")) continue;
    requireKey(key, file);
  }
}
for (const file of [
  "Tinycast/Features/Settings/SettingsAnchor.swift",
  "Tinycast/Features/Backup/Model/BackupCategory.swift",
]) {
  for (const match of read(file).matchAll(/(?:title|label|countNoun):\s*(?:String\(localized:\s*)?"([^"\\]+)"/g)) {
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
      if (table[key] && table[key] !== key) {
        problems.push(path.relative(root, file) + ": Text(" + name + ") receives untranslated literal “" + key + "”");
      }
    }
  }
}
let extractedCount = 0;
if (args.length) {
  const extracted = args[1].endsWith(".xcstrings") ? JSON.parse(read(args[1])).strings : plist(args[1]);
  for (const key of Object.keys(extracted)) requireKey(key, args[1]);
  extractedCount = Object.keys(extracted).length;
}
if (problems.length) {
  console.error(problems.map((problem) => `FAIL: ${problem}`).join("\n"));
  process.exit(1);
}
console.log(`Localization checks passed: ${Object.keys(table).length} keys, ${catalogs.length + 2} source catalogs, ${checkedProperties} computed Text properties${extractedCount ? `, ${extractedCount} extracted keys` : ""}.`);
console.log("Dynamic user content and unregistered rendering paths still require native UI inspection.");
