"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const { test } = require("node:test");

const root = path.resolve(__dirname, "..");
test("localization gate rejects missing keys and known rendering regressions", () => {
  const fixture = fs.mkdtempSync(path.join(os.tmpdir(), "tinycast-localization-test-"));
  try {
    fs.mkdirSync(path.join(fixture, "Scripts"));
    fs.copyFileSync(path.join(root, "Scripts/check-localization.js"), path.join(fixture, "Scripts/check-localization.js"));
    fs.copyFileSync(path.join(root, "Scripts/check-localizations.js"), path.join(fixture, "Scripts/check-localizations.js"));
    fs.cpSync(path.join(root, "Tinycast"), path.join(fixture, "Tinycast"), {
      recursive: true,
      filter: (file) => !file.endsWith(".generated.swift") && !file.includes("Assets.xcassets"),
    });
    const check = (...args) => spawnSync(process.execPath, [path.join(fixture, "Scripts/check-localization.js"), ...args], {
      encoding: "utf8",
    });
    const expectFailure = (fragment) => {
      const result = check();
      assert.equal(result.status, 1, result.stdout + result.stderr);
      assert.ok(result.stderr.includes(fragment), result.stderr);
    };
    const initial = check();
    assert.equal(initial.status, 0, initial.stdout + initial.stderr);
    const tablePath = path.join(fixture, "Tinycast/Resources/Localizable.xcstrings");
    const table = fs.readFileSync(tablePath, "utf8");
    for (const key of ["Navigate back or close window", "Larger"]) {
      const catalog = JSON.parse(table);
      delete catalog.strings[key];
      const changed = JSON.stringify(catalog, null, 2);
      assert.notEqual(changed, table, `Fixture has no ${key} key`);
      fs.writeFileSync(tablePath, changed);
      expectFailure(`missing “${key}”`);
    }
    fs.writeFileSync(tablePath, table.replace('  "strings" : {', '  "strings" : {\n    "Snippets" : {},'));
    expectFailure("Duplicate key: Snippets");
    const malformed = JSON.parse(table);
    malformed.strings.Snippets.localizations["zh-Hans"].stringUnit.value = "回归 %lld";
    malformed.strings["Regression %@"] = structuredClone(malformed.strings.Snippets);
    fs.writeFileSync(tablePath, JSON.stringify(malformed, null, 2));
    expectFailure("has specifiers");
    const missingLanguage = JSON.parse(table);
    delete missingLanguage.strings.Snippets.localizations.fr;
    fs.writeFileSync(tablePath, JSON.stringify(missingLanguage, null, 2));
    expectFailure("has no fr translation");
    const empty = JSON.parse(table);
    empty.strings.Snippets.localizations["zh-Hans"].stringUnit.value = "";
    fs.writeFileSync(tablePath, JSON.stringify(empty, null, 2));
    expectFailure("Empty translation");
    fs.writeFileSync(tablePath, table);
    const legacyFolder = path.join(fixture, "Tinycast/zh-Hans.lproj");
    fs.mkdirSync(legacyFolder, { recursive: true });
    const legacyPath = path.join(legacyFolder, "Localizable.strings");
    fs.writeFileSync(legacyPath, '"Snippets" = "文本片段";\n');
    expectFailure("duplicates compiled catalog output");
    fs.rmSync(legacyPath);
    const extractedPath = path.join(fixture, "Localizable.xcstrings");
    fs.writeFileSync(extractedPath, JSON.stringify({
      sourceLanguage: "en", strings: { "Source-only regression key": {} }, version: "1.0",
    }));
    const extracted = check("--extracted", extractedPath);
    assert.equal(extracted.status, 1, extracted.stdout + extracted.stderr);
    assert.ok(extracted.stderr.includes("missing “Source-only regression key”"), extracted.stderr);
    fs.writeFileSync(extractedPath, table);
    const covered = check("--extracted", extractedPath);
    assert.equal(covered.status, 0, covered.stdout + covered.stderr);
    fs.writeFileSync(tablePath, table);
    const viewPath = path.join(fixture, "Tinycast/Features/WindowManagement/Settings/WindowLayoutsSection.swift");
    const view = fs.readFileSync(viewPath, "utf8");
    const changed = view.replace(
      'String(localized: "Save an arrangement, then restore it with one shortcut.")',
      '"Save an arrangement, then restore it with one shortcut."',
    );
    assert.notEqual(changed, view, "Fixture no longer models the original empty-state regression");
    fs.writeFileSync(viewPath, changed);
    expectFailure("Text(emptyMessage) receives untranslated literal");
    fs.writeFileSync(viewPath, view);
    assert.equal(check().status, 0);
  } finally {
    fs.rmSync(fixture, { recursive: true, force: true });
  }
});
