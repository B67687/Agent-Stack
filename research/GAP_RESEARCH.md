# Gap Research Results — 2026-07-06

## 1. Watcher-Ignore (manual compilation from .gitignore aggregator knowledge)

Below is the exhaustive list of patterns for `.opencode/watcher-ignore` (or `watcher.ignore` in opencode.jsonc), compiled from knowledge of all major ecosystems' build artifacts, cache directories, editor temp files, and OS noise files.

### Build Artifacts (by ecosystem)

**Node/JS/TS:** node_modules/**, dist/**, build/**, .next/**, .turbo/**, .nuxt/**, .output/**, .svelte-kit/**, .expo/**, storybook-static/**, out/**, .serverless/**, .webpack/**, .parcel-cache/**, .cache/esbuild/**, .docusaurus/**, .cache/**

**Python:** __pycache__/**, *.pyc, *.pyo, *.pyd, .venv/**, venv/**, .tox/**, .nox/**, .mypy_cache/**, .ruff_cache/**, .pytest_cache/**, .hypothesis/**, *.egg-info/**, dist/**, build/**, .eggs/**, pip-wheel-metadata/**, .pyre/**, .pytype/**, .dmypy.json

**Rust:** target/**, **/target/**, Cargo.lock (project-specific)

**Go:** vendor/**, **/*.cover, **/coverage.out, **/*.test, **/*.test.exe

**Java/Kotlin:** **/build/**, **/target/**, **/*.class, **/*.jar, **/*.war, **/*.ear, .gradle/**, gradle/wrapper/gradle-wrapper.jar

**C/C++:** **/build/**, **/*.o, **/*.obj, **/*.exe, **/*.dll, **/*.dylib, **/*.so, **/*.a, **/*.lib, **/*.out

**Ruby:** vendor/bundle/**, .bundle/**, **/*.gem

**Elixir:** _build/**, deps/**

**Haskell:** .stack-work/**, dist-newstyle/**, **/*.hi, **/*.o

**Zig:** zig-out/**, .zig-cache/**

**Terraform:** .terraform/**, **/.terraform.lock.hcl

**Docker:** .docker/**

### Package Manager Locks (read-only, change-only. No watcher needed)
*.lock, package-lock.json, yarn.lock, pnpm-lock.yaml, bun.lockb, Gemfile.lock, Cargo.lock, poetry.lock, uv.lock, requirements.txt (generated), Pipfile.lock, composer.lock, mix.lock

### IDE & Editor Temp Files
**Vim:** *.swp, *.swo, *.swn, *.swx, *.swm
**Emacs:** *~, \#*\#, .\#*
**JetBrains:** .idea/**, *.iml, *.ipr, *.iws, .idea_modules/**
**VS Code:** .history/**, **/*.code-workspace
**Eclipse:** .classpath, .project, .settings/**
**Xcode:** *.xcworkspace, *.xcuserdata, DerivedData/**, **/*.xcworkspace/xcshareddata

### OS Noise Files
**macOS:** .DS_Store, .DS_Store?*, .Spotlight-V100, .Trashes, ._*, .AppleDouble, .LSOverride, Icon?, ehthumbs.db
**Windows:** Thumbs.db, ehthumbs.db, Desktop.ini, $RECYCLE.BIN/
**Linux:** .Trash-*, .trash-*

### Logs & Temporary Files
**/*.log, logs/**, *.tmp, *.temp, .*history, .npm/**, .yarn/**, .pnpm-store/**, .eslintcache, .stylelintcache, .prettiercache

### Secrets (already in deny-lists but good for watcher too)
.env, .env.*, secrets/**, *.pem, credentials*, *.key

**Total: ~120+ patterns.** For a `.opencode/watcher-ignore` file using gitignore syntax, this is about 60 lines. For inline `watcher.ignore` in opencode.jsonc, we'd pick the top 30.

---

## 2. Tool-Scoped Agents Analysis (manual)

### Source: joelhooks/opencode-config

joelhooks defines 3 scope-restricted agents:

1. **test-writer** — `write` restricted to `**/*.test.ts`, `**/*.spec.ts`, `**/*.test.tsx`, `**/*.spec.tsx`. All other write denied.
2. **docs** — `write` restricted to `**/*.md`, `**/*.mdx`. All other write denied.
3. **security** — `write`/`edit`/`patch` all denied. Read-only Snyk scanner.

### How it works

OpenCode's `permission.write` block supports glob keys:
```json
"permission": {
  "write": {
    "**/*.test.ts": "allow",
    "**/*.spec.ts": "allow",
    "*": "deny"
  }
}
```
Last matching rule wins. The catch-all `*` at the end denies everything except the explicit allows.

### Reliability assessment

This is **OpenCode's native permission system**, not a hack. The `permission.write` block is a documented first-class citizen. OMO inherits it. The pattern is well-known in the community — seen in multiple configs: joelhooks, 5kahoisaac (read deny patterns), and OpenCode's own issue tracker examples.

**Known issues:**
- Agent may fail confusingly when trying to write outside scope — OpenCode returns a permission error, not a graceful "that's not in my scope" message
- Requires explicit `"*": "deny"` catch-all at end (last rule wins, not first)
- Agents don't know their scope until they hit a denial — no built-in pre-flight check

**Why OMO doesn't ship this:** It's an OpenCode-native feature, not an OMO feature. OMO adds agent routing (which model to use), not agent permission scoping. OpenCode's config schema owns permissions. OMO's `AgentOverrideConfigSchema` only supports override on top-level permission keys, not per-agent write-scope nesting. You'd define the agent directly in `opencode.jsonc` with the tool scoping, not in `oh-my-openagent.jsonc`.

### Recommendation: ADOPT but only for test agent

| Agent | Value | Effort |
|-------|-------|--------|
| test-writer | High — prevents test-gen scope creep | 30 min |
| docs | Medium — docs agent is less used | 15 min |
| security | Low — we already have security-research command | 5 min |

Add a `test-writer` agent to opencode.jsonc that:
- Uses free-tier model (cheap for test gen)
- Write restricted to `**/*.test.*`, `**/*.spec.*`, `**/*.test.*.snap`
- Has a dedicated `/write-tests` command

---

## 3. Ask-Tier Permissions (from successful research agent)

### OpenCode supports it — full syntax confirmed

```json
"bash": {
  "": "allow",           // default allow 
  "sudo *": "ask",       // ask for privilege escalation
  "git push --force *": "ask",
  "git reset --hard *": "ask",
  "npm publish *": "ask",
  "eval *": "ask"
}
```

### Key findings from research:

1. **Syntax is last-rule-wins** — put catch-all first, specific overrides after
2. **Ask prompt gives 3 options**: "once" | "always" (session-only) | "reject" — NO double confirmation
3. **`--auto` flag** auto-approves ask prompts while still enforcing deny — gives speed + safety
4. **Major community complaint**: "always" option is session-only, doesn't persist to config
5. **OMO supports ask tier** via AgentOverrideConfigSchema

### Optimal ask-list (feiskyer + community consensus):

| Command | Reason | Our status |
|---------|--------|-----------|
| `sudo *` | Privilege escalation | Currently DENY (too restrictive) |
| `git push --force *` | History rewrite | Currently ALLOW (too permissive) |
| `git reset --hard *` | Local data loss | Not in config |
| `npm publish *` | Registry mutation | Not in config |
| `eval *` | Code injection | Not in config |
| `chmod 777 *` | Dangerous perms | Not in config |
| `docker *` | Container ops | Not in config |
| `kubectl *` | Infra mutation | Not in config |

### Recommendation: CHANGE current deny rules to ask rules

We currently have blanket DENY on: sudo, rm -rf, chown, mkfs, dd, shutdown, reboot, poweroff, and blanket ALLOW on everything else.

**Better:** DENY stays on catastrophic (rm -rf /, mkfs, dd, shutdown, reboot, poweroff). ASK on semi-dangerous (sudo, git push --force, npm publish, eval, chmod 777). ALLOW everything else.

This makes sudo accessible (currently impossible) while keeping the safety prompt.

---

*Compiled 2026-07-06 from manual research + successful librarian agent result (bg_baad425c)*

---

## 4. V2 Gaps Closed (2026-07-10)

Four practitioner-identified gaps were researched alongside the above and **closed in this session**:

| # | Gap | Implementation | Status |
|---|-----|---------------|--------|
| 1 | **Auto-Rules System** | 7 `.mdc` rule files in `.opencode/rules/` (rust-workflow, python-workflow, typescript-react, config-files, git-workflow, go-workflow, agent-behavior) — auto-activated by path glob patterns | [CLOSED] 2026-07-10 |
| 2 | **Agent Prompt Specialization** | 10 `prompt_append` entries added to `oh-my-openagent.jsonc` (general, librarian, metis, momus, oracle, scout, sisyphus-junior, review, test-writer, worker) — total 14 prompt_append entries across all agents | [CLOSED] 2026-07-10 |
| 3 | **Context-Mode Tooling** | `ctx_search`/`ctx_index`/`ctx_fetch_and_index` wired into sisyphus (opencode.jsonc) + librarian + general (oh-my-openagent) prompts. Enables memory-backed agent workflow. | [CLOSED] 2026-07-10 |
| 4 | **Automation Scripts** | 3 new scripts in `scripts/`: post-agent-log.sh, pre-commit-verify.sh, health-check.sh | [CLOSED] 2026-07-10 |

### Gaps #1-3 (above) remain OPEN — deferred to future session

| # | Gap | Research Source |
|---|-----|----------------|
| 1 | Watcher-Ignore Patterns (120+ patterns catalogued in §1) | §1 of this doc |
| 2 | Tool-Scoped Agents (write-scoped test-writer, docs, security agents from joelhooks pattern) | §2 of this doc |
| 3 | Ask-Tier Permissions (sudo, git push --force, npm publish, eval change from DENY to ASK) | §3 of this doc |

Additional deferred gaps (from practitioner comparison, not yet researched): model tiering, per-project overrides.
