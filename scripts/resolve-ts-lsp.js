#!/usr/bin/env node
const { spawn } = require("child_process");
const fs = require("fs");
const path = require("path");

// Resolve the REAL typescript-language-server binary. This wrapper is itself
// named "typescript-language-server" and sits first in PATH — spawning it by
// name used to recurse into itself (fork-bomb chain of 500+ node processes),
// filling the systemd ssh.service pids cgroup (TasksMax=4096) until thread
// creation failed with EAGAIN and opencode aborted (SIGABRT, "core dumped").
const REAL_TLS =
  process.env.TYPESCRIPT_LANGUAGE_SERVER ||
  path.join(path.dirname(process.execPath), "typescript-language-server");

function resolveTypeScript(workspaceRoot) {
  try {
    const tsPkgPath = require.resolve("typescript/package.json", {
      paths: [workspaceRoot],
    });
    const tsPkgDir = path.dirname(tsPkgPath);
    const tsPkg = JSON.parse(fs.readFileSync(tsPkgPath, "utf8"));
    const major = parseInt(tsPkg.version.split(".")[0], 10);

    if (major >= 7) {
      const platPkg = `@typescript/typescript-${process.platform}-${process.arch}`;
      let goBinary;
      try {
        const platPkgJson = require.resolve(platPkg + "/package.json", {
          paths: [tsPkgDir],
        });
        goBinary = path.join(path.dirname(platPkgJson), "lib", "tsc");
      } catch {
        goBinary = path.resolve(
          tsPkgDir,
          "..",
          "node_modules",
          platPkg,
          "lib",
          "tsc",
        );
      }
      if (fs.existsSync(goBinary)) {
        return {
          command: [goBinary, "--lsp", "--stdio"],
          type: "ts7-native",
          version: tsPkg.version,
        };
      }
    }
    return {
      command: [REAL_TLS, "--stdio"],
      type: "ts6-legacy",
      version: tsPkg.version,
    };
  } catch {
    return {
      command: [REAL_TLS, "--stdio"],
      type: "fallback",
      version: "unknown",
    };
  }
}

const workspaceRoot = process.cwd();
const result = resolveTypeScript(workspaceRoot);

console.error(
  "[resolve-ts-lsp] " +
    JSON.stringify({
      type: result.type,
      source: "workspace-local",
      version: result.version,
      command: result.command.join(" "),
    }),
);

const [cmd, ...args] = result.command;

// Recursion guard: never spawn ourselves or a missing binary — a loop here is
// what saturated the pids cgroup and crashed opencode.
if (!fs.existsSync(cmd)) {
  console.error("[resolve-ts-lsp] FATAL: LSP binary not found: " + cmd);
  process.exit(1);
}
if (fs.realpathSync(cmd) === __filename) {
  console.error(
    "[resolve-ts-lsp] FATAL: refusing to spawn ourselves (recursion guard)",
  );
  process.exit(1);
}

const server = spawn(cmd, args, { stdio: ["pipe", "pipe", "inherit"] });

// Buffer for incoming data (LSP JSON-RPC with Content-Length headers)
let incomingBuf = "";

// Fix: TS7 Go LSP requires `initialized` notification to have `"params": {}`
// The daemon sends it without params, which causes InvalidParams → ServerNotInitialized → crash

function fixMessage(raw) {
  try {
    const parsed = JSON.parse(raw);
    if (
      parsed.method === "initialized" &&
      (parsed.params === undefined || parsed.params === null)
    ) {
      parsed.params = {};
      return JSON.stringify(parsed);
    }
  } catch {}
  return raw;
}

// Parse incoming LSP frames from stdin (daemon → server)
// LSP format: Content-Length: N\r\n\r\n{json}
let buffer = "";
process.stdin.on("data", (chunk) => {
  buffer += chunk.toString("utf-8");

  while (true) {
    const headerMatch = buffer.match(/^Content-Length:\s*(\d+)\r?\n\r?\n/);
    if (!headerMatch) break;

    const contentLength = parseInt(headerMatch[1], 10);
    const headerEnd = headerMatch[0].length;
    const totalLength = headerEnd + contentLength;

    if (buffer.length < totalLength) break;

    const jsonStr = buffer.substring(headerEnd, totalLength);
    const fixed = fixMessage(jsonStr);

    const fixedHeader = `Content-Length: ${Buffer.byteLength(fixed)}\r\n\r\n`;
    server.stdin.write(fixedHeader + fixed);

    buffer = buffer.substring(totalLength);
  }
});

server.stdout.pipe(process.stdout);

server.on("exit", (code) => {
  process.exit(code ?? 0);
});

process.on("SIGTERM", () => server.kill("SIGTERM"));
process.on("SIGINT", () => server.kill("SIGINT"));
