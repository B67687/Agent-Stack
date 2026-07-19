# ADR 013: TypeScript 7 Native LSP

**Status:** Accepted  
**Date:** 2026-07-19

## Context

OpenCode uses a builtin TypeScript LSP server wired through typescript-language-server. The server is configured as `typescript-language-server --stdio` in the LSP daemon's user config (`~/.config/opencode/lsp.json`).

typescript-language-server is a wrapper around `tsserver.js`. It translates LSP requests into tsserver protocol and back. This worked reliably through the TypeScript 5.x and 6.x series.

TypeScript 7.0.2 removed `tsserver.js` and `tsserverlibrary.js` entirely — these were the only protocol bridge typescript-language-server knew. Version 5.3.0 of typescript-language-server always appends `tsserver.js` to the resolved TypeScript path and fails with "Could not find a valid TypeScript installation" when the file is absent.

TypeScript 7 ships a native LSP server as a Go binary (23 MB, statically linked) in a platform-specific npm package (`@typescript/typescript-linux-x64`). The Go binary speaks LSP natively and is accessible directly with `--lsp --stdio`. It is the intended replacement for tsserver.

### Root Cause Discovered

The LSP daemon sends the `initialized` notification as `{"method":"initialized"}` without a `params` field. Per JSON-RPC spec, `params` is optional for notifications. However, TS7's Go LSP **requires** `"params":{}`. Without it, the server rejects the notification with `InvalidParams`, stays in `ServerNotInitialized` state, and crashes with a nil pointer dereference in `getSnapshot` when any document request arrives. This is a bug in the TS7 Go LSP implementation.

The fix is applied in the resolver script: it intercepts daemon → Go binary messages, parses them, and adds `"params":{}` to any `initialized` notification that lacks it. The same bug affects zls 0.16.0 (see ADR 014).

The workspace must maintain compatibility across two regimes:

- **TS 7+** (current global install): must use the Go binary directly.
- **TS 6-** (some projects, CI images): can use typescript-language-server.

A single static command cannot handle both regimes.

## Decision

Write a detection script at `Agent-Stack/scripts/resolve-ts-lsp.js` that probes the TypeScript installation at startup and dispatches to the correct server.

The resolution strategy, in order of precedence:

1. **Workspace-local TypeScript** via `require.resolve("typescript/package.json")`. If major >= 7, resolve the platform-specific Go binary directly (`@typescript/typescript-{platform}-{arch}/lib/tsc`) and spawn it with `--lsp --stdio`. If major <= 6, spawn `typescript-language-server --stdio`.
2. **Global TypeScript** from PATH (`which tsc`). Same version routing.
3. **typescript-language-server** alone, as best-effort fallback.
4. **Bare `tsc --lsp --stdio`** as final fallback, logging a warning.

The script is a transparent stdio proxy. It spawns the resolved server and pipes stdin/stdout/stderr bidirectionally. It also intercepts and fixes the `initialized` notification format (adds `"params":{}` when missing).

### Config Location

The config must be written to the LSP daemon's user config file at `~/.config/opencode/lsp.json`, pointed to by `LSP_TOOLS_MCP_USER_CONFIG`. The daemon does NOT read the `lsp` section from `opencode.jsonc`. Project config paths (`.opencode/lsp.json`, `.omo/lsp.json`) use a code path that always ignores custom commands and falls back to builtins.

### Symlink

`~/.local/bin/typescript-language-server` is symlinked to `resolve-ts-lsp` so that any caller using the old binary name still gets the version-aware dispatcher.

## Consequences

- **Positive:** Single config entry works across TS 6 and TS 7. No manual version gating.
- **Positive:** Native Go LSP eliminates the protocol translation layer, reducing latency.
- **Positive:** Fallback chain degrades gracefully rather than failing hard.
- **Positive:** Logging to stderr preserves operator visibility.
- **Negative:** Extra `node` process on every LSP startup adds ~50ms to initialization.
- **Negative:** The `initialized` notification fix is a workaround for a TS7 Go LSP bug. Must be updated or removed when Microsoft fixes the upstream issue.
- **Negative:** Detection depends on `require.resolve` and `which`. Nvm/nix/snap setups may resolve inconsistently.
- **Neutral:** Requires `typescript` in `node_modules` for local detection. Global-only installs still supported via strategy 2.

## Alternatives Considered

**Symlink `tsserver.js` shim.** A stub at the old path that re-exports to the Go LSP. Fragile — breaks on every TypeScript reinstall.

**Hard fork of typescript-language-server.** Patch to detect TS 7+. Maintainable but introduces a dead npm fork once TS7 stabilization finishes.

**Static config per workspace.** Each project defines its own LSP command. Defeats the purpose of a single Agent Stack config.

**Patch the daemon to send correct initialized params.** The correct long-term fix but touches compiled/bundled daemon code.

**Use old typescript-language-server for all TS versions.** Loses native Go LSP benefits and breaks when typescript-language-server stops supporting tsserver.

## Compliance

1. `Agent-Stack/scripts/resolve-ts-lsp.js` exists and is executable.
2. `/home/nami/.config/opencode/lsp.json` contains a `typescript` entry with the absolute path to `resolve-ts-lsp`.
3. `resolve-ts-lsp --version` outputs `"type":"ts7-native"` on a TS 7+ system.
4. On a TS 6- system: shows `"type":"ts6-legacy"`.
5. `lsp_diagnostics` returns TypeScript errors (verified: catches `TS2322`).
6. `~/.local/bin/typescript-language-server` is a symlink to the resolver.
