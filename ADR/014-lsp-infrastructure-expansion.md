# ADR 014: LSP Infrastructure Expansion

**Status:** Accepted — partially SUPERSEDED (2026-08-01): 4 of the added servers (jdtls, lua-ls, zls wrapper, kotlin-lsp.sh) were later REMOVED as dead wrappers; the standalone `lsp.json` was retired. Live LSP set = basedpyright, css, html, json, markdown, rust-analyzer, typescript (all bare names in the `lsp` section of `opencode.jsonc`). **Further superseded (2026-08-03):** kotlin-ls REMOVED from the live set — zero Kotlin in user projects (only refs in the upstream `omo/` source clone, not user code).
**Date:** 2026-07-19

## Context

The workspace uses OpenCode v4 with the LSP daemon managing 42 builtin servers. Before this ADR, 15 were installed and working. We identified coverage gaps and two broken servers.

TypeScript was resolved separately in ADR 013 (Go native LSP + `initialized` notification fix). The same `initialized` params bug also affected zls.

This ADR expands the active LSP set from 15 to 19 by adding 4 new servers, fixing 2 broken ones, and applying workarounds for a daemon message-format issue. (SUPERSEDED as of 2026-08-01 — see status note.)

Languages deliberately skipped: PHP, Ruby, Elixir, Dart, Haskell, R — not used. C/C++ (clangd) deferred until C/C++ projects arrive.

## Decision

### New Installation: kotlin (Kotlin)

JetBrains publishes a Kotlin LSP server as a tarball. The builtin binary name is `kotlin-server` but OpenCode's builtin expects `kotlin-lsp`. The actual community tooling name is `kotlin-ls` (without P).

- Download from `download-cdn.jetbrains.com/language-server/kotlin-server/`
- Extract to `~/.local/share/kotlin-lsp/`
- Create `~/.local/bin/kotlin-ls` → symlink to `bin/intellij-server`
- Create `~/.local/bin/kotlin-lsp` → wrapper that calls `kotlin-ls --stdio` (binary name fix + stdio mode flag) — REMOVED 2026-08-01: config now uses bare `kotlin-ls` directly; wrapper was dead code
- Prerequisite: Java 17+ (already present)

### New Installation: texlab (LaTeX)

Standalone Rust binary, v5.26.0 from GitHub releases. Placed at `~/.local/bin/texlab`. No runtime dependencies. Auto-detected by OpenCode.

### New Installation: csharp (C#)

`csharp-ls` (razzmatazz/csharp-language-server) installed via `dotnet tool install --global csharp-ls`. Binary at `~/.dotnet/tools/csharp-ls`. Symlinked into `~/.local/bin/csharp-ls` for reliable PATH resolution. OpenCode's builtin expects `omnisharp` — works via binary name alias.

LSP starts correctly but requires a `.csproj`/`.sln` file in the workspace to provide full diagnostics (expected behavior).

### New Installation: jdtls (Java) — SUPERSEDED (REMOVED 2026-08-01: dead wrapper, Java not in live config)

Eclipse JDT Language Server snapshot. Downloaded from `download.eclipse.org/jdtls/snapshots/`. Wrapper script at `~/.local/bin/jdtls` invokes Java 21 with:

- `-configuration $CONFIG_DIR` (OSGi config path)
- `-data $DATA_DIR` (workspace metadata directory)
- `-Dosgi.sharedConfiguration.area.readOnly=true` + `cascaded=true`

Java 21 installed alongside existing Java 17 (system default remains 17).

### Fix: typescript

Resolved in ADR 013. Detection script `resolve-ts-lsp.js` probes workspace TS version and dispatches to the TS7 Go native LSP or typescript-language-server. Also fixes the daemon's `initialized` notification format (adds `"params":{}`).

### Fix: zls (Zig) — SUPERSEDED (REMOVED 2026-08-01: zls wrapper + zig deleted, not in live config)

zls 0.16.0 was installed via npm but crashed with `ParseError`. Two issues:

1. **Missing zig compiler** — downloaded zig 0.14.0 from ziglang.org, placed at `~/.local/bin/zig`.
2. **Same `initialized` notification bug as TS7** — created `zls-lsp-wrapper` (Node.js proxy) that intercepts messages and adds `"params":{}` to `initialized`. Symlinked `~/.local/bin/zls` to the wrapper.

### Fix: lua-ls — SUPERSEDED (REMOVED 2026-08-01: wrapper deleted, not in live config)

lua-ls was installed but its binary `lua-language-server` expects to be run from the directory containing `main.lua`. Created a wrapper at `~/.local/bin/lua-ls` that sets the correct working directory.

### LSP Config Discovery — SUPERSEDED (2026-08-01: standalone lsp.json retired; live LSP config is the `lsp` section of `opencode.jsonc`, bare command names)
####

The LSP daemon reads config from files specified by environment variables:

- `LSP_TOOLS_MCP_USER_CONFIG` → `~/.config/opencode/lsp.json`
- `LSP_TOOLS_MCP_PROJECT_CONFIG` → `.opencode/lsp.json`, `.omo/lsp.json`, `.omo/lsp-client.json`

Created `~/.config/opencode/lsp.json` with explicit command overrides for `typescript` and `kotlin-ls`. The daemon ignores the `lsp` section in `opencode.jsonc`.

## Consequences

- **Positive:** Coverage expanded from 15 to 19 installed LSPs.
- **Positive:** All new LSPs are standalone binaries or JVM-based. No heavy toolchains required.
- **Positive:** Java 21 isolated in jdtls wrapper; system Java 17 unaffected. (jdtls removed 2026-08-01)
- **Positive:** `initialized` notification fix unblocks both TS7 and zls with the same pattern.
- **Negative:** Java version duality adds maintenance surface for Java 21 updates.
- **Negative:** csharp-ls requires a project file (`csproj`) to function — no unprojected file diagnostics.
- **Negative:** Dotnet tools PATH is shell-specific; symlink to `~/.local/bin` bypasses this.
- **Negative:** The `initialized` fix works around a daemon message format issue. If the daemon is updated to send proper params, the wrappers can be removed.
- **Neutral:** texlab auto-detected with no config change.
- **Neutral:** jdtls wrapper must be updated when JDTLS snapshot is upgraded.

## Alternatives Considered

**Install only JDTLS, skip kotlin-ls.** Kotlin projects could use IntelliJ's builtin LSP. Rejected — workflow is editor-agnostic.

**Use omnisharp for C# instead of csharp-ls.** omnisharp requires Mono on Linux. csharp-ls runs on .NET SDK alone. csharp-ls chosen for lighter footprint.

**Install Java 21 as system default.** Would break Kotlin tooling expecting Java 17. Side-by-side install chosen.

**Skip jdtls; use Kotlin LSP for everything.** Rejected — Kotlin server doesn't handle Java files.

**Install zig from snap/apt.** Snap lags behind. Direct binary from ziglang.org chosen.

**Use `cargo install texlab`.** Compiles from source (slow). Binary release used instead.

## Compliance

1. `kotlin-ls` binary exists in `~/.local/bin/`. `lsp_diagnostics` on `.kt` files returns clean diagnostics. (the `kotlin-lsp` wrapper was removed 2026-08-01)
2. `texlab` exists in `~/.local/bin/`. `lsp_diagnostics` on `.tex` files returns clean diagnostics.
3. ~~`jdtls` wrapper invokes Java 21~~ — OBSOLETE: jdtls removed 2026-08-01.
4. `csharp-ls` exists at `~/.local/bin/csharp-ls`. LSP starts correctly (diagnostics require a `.csproj` workspace).
5. ~~`zls` wrapper resolves `initialized` fix~~ — OBSOLETE: zls + wrapper removed 2026-08-01.
6. ~~`lua-ls` wrapper points to correct `main.lua`~~ — OBSOLETE: wrapper removed 2026-08-01.
7. ~~`~/.config/opencode/lsp.json` exists~~ — OBSOLETE: lsp.json retired 2026-08-01; typescript/kotlin-ls overrides now live in `opencode.jsonc` `lsp` section.
8. `java --version` reports Java 17 (system default unchanged).
9. `resolve-ts-lsp --version` returns `"type":"ts7-native"`.
10. ~~`~/.local/bin/zls` is a symlink to `zls-lsp-wrapper`~~ — OBSOLETE: removed 2026-08-01.
11. `~/.local/bin/typescript-language-server` is a symlink to `resolve-ts-lsp`.
