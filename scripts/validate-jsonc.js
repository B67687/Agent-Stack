#!/usr/bin/env node
// JSONC validator + query helper using jsonc-parser.
// Usage:
//   validate-jsonc.js check <file>        → exits 0 if valid, 1 with error
//   validate-jsonc.js parse <file>         → print parsed JSON to stdout
//   validate-jsonc.js get <file> <path>    → get value at dot-path (e.g. "background_task.modelConcurrency")
//   validate-jsonc.js keys <file>          → list top-level keys
//   validate-jsonc.js bracean <file>       → count braces outside strings, report imbalance
const path = require("path");
const { execSync } = require("child_process");
// Add global node_modules to resolve path for jsonc-parser
const globalNodeModules = execSync("npm root -g", { encoding: "utf8" }).trim();
module.paths.push(globalNodeModules);

const { parse, ParseErrorCode } = require("jsonc-parser");
const fs = require("fs");

const cmd = process.argv[2];
const filePath = process.argv[3];

if (!cmd || !filePath) {
  console.error(
    "Usage: validate-jsonc.js <check|parse|get|keys|bracean> <file> [path]",
  );
  process.exit(1);
}

const content = fs.readFileSync(filePath, "utf8");
const errors = [];
const parsed = parse(content, errors, {
  allowTrailingComma: true,
  disallowComments: false,
});

function bail(msg) {
  console.error(msg);
  process.exit(1);
}

switch (cmd) {
  case "check":
    if (errors.length > 0) {
      errors.forEach((e) => {
        const line =
          (content.substring(0, e.offset).match(/\n/g) || []).length + 1;
        console.error(
          `  Error ${e.error} (${ParseErrorCode[e.error] || "?"}) at offset ${e.offset}, line ${line}`,
        );
      });
      process.exit(1);
    }
    process.exit(0);

  case "parse":
    if (errors.length > 0) bail("Parse errors: " + errors.length);
    console.log(JSON.stringify(parsed, null, 2));
    process.exit(0);

  case "get": {
    if (errors.length > 0) bail("Parse errors");
    const path = process.argv[4] || "";
    const parts = path.split(".");
    let val = parsed;
    for (const p of parts) {
      if (val && typeof val === "object" && p in val) val = val[p];
      else bail(`Path "${path}" not found (stopped at "${p}")`);
    }
    console.log(typeof val === "string" ? val : JSON.stringify(val));
    process.exit(0);
  }

  case "keys":
    if (errors.length > 0) bail("Parse errors");
    Object.keys(parsed).forEach((k) => console.log(k));
    process.exit(0);

  case "bracean": {
    // Count brace balance excluding strings and comments
    let cleaned = content
      .replace(/\/\/.*$/gm, " ")
      .replace(/\/\*[\s\S]*?\*\//g, " ");
    let result = "",
      inStr = false,
      esc = false;
    for (let i = 0; i < cleaned.length; i++) {
      const ch = cleaned[i];
      if (esc) {
        esc = false;
        continue;
      }
      if (ch === "\\" && inStr) {
        esc = true;
        continue;
      }
      if (ch === '"') {
        inStr = !inStr;
        continue;
      }
      if (inStr) continue;
      result += ch;
    }
    const opens = (result.match(/\{/g) || []).length;
    const closes = (result.match(/\}/g) || []).length;
    if (opens !== closes) {
      console.error(
        `Braces: ${opens} open, ${closes} close (${opens - closes} unclosed)`,
      );
      process.exit(1);
    }
    console.log(`${opens} = ${closes} (balanced)`);
    process.exit(0);
  }

  default:
    bail(`Unknown command: ${cmd}`);
}
