---
name: rust-workflow
description: "MUST USE for any Rust edit/test cycle. Covers cargo check vs test discipline, incremental test writing, lossy roundtrip fixture patterns, systematic API pre-verification, Rust 2024 edge cases (gen keyword), and all patterns learned from Wave 1 of the ithmb-finale plan. Load for any non-trivial Rust code generation or debugging session."
---
> Policy source: `.opencode/rules/rust-workflow.mdc` (always injected). This skill is the operational playbook and must stay consistent with that policy — it may add procedural detail, never contradict.


# Rust Workflow

Use this skill when writing Rust code — especially when generating tests or iterating on edit→compile→fix cycles. The patterns here prevent the common failure modes that burn tokens on compile-error loops.

## Tool Workflow (token efficiency)

**Primary compile verification order (fastest first):**

1. **`lsp_diagnostics`** — instant, no cargo needed. Use after every single-file edit to catch syntax/type errors inline.
2. **`cargo check`** — ~5s. Catches all type/borrow/syntax errors. Use this 90% of the time for compile verification. NEVER use `cargo test` just to check compiles.
3. **`cargo test --no-run`** — ~15s. Compiles tests without executing them. Use when test-specific compilation errors are suspected (wrong import, missing test module, cfg issue).
4. **`cargo clippy`** — ~10s with fresh check. For lint verification.
5. **`cargo clippy --fix`** — auto-fixes mechanical lints (uninlined_format_args, unused imports, redundant clones, needless_range_loop). Use this BEFORE manual fixes — it handles 60% of clippy issues automatically.
6. **`cargo test`** — 40-60s. Only after check + clippy both pass.

**Bad patterns (avoid):**
- ❌ Running `cargo test` to check compiles — wastes 40s running 522 tests for a syntax fix
- ❌ Fixing clippy `uninlined_format_args` by hand — `clippy --fix` does it
- ❌ Reading full `cargo test` output — tail `-20` lines is almost always enough

## Code Generation Patterns

### Test file strategy (learned the hard way in ithmb-finale Wave 1)

**DO**: Write tests in batches of 3-4 functions, then `cargo check`.
**DON'T**: Write a 400+ LOC monolithic test file with 11 tests in one shot.

Why: A big file with systematic errors (wrong API, missing braces, moved values) means all 11 tests fail the same way. Fixing one batch of 4 is cheap; fixing 11 at once requires re-editing the whole file.

**Batting practice:**
1. Write 3-4 test function stubs
2. `cargo check` — catches API name errors, wrong signature, missing imports
3. Fill in assertion bodies for those 3-4
4. `cargo check` again
5. `cargo test --no-run` + `cargo test --test <name>` for the batch
6. Move to next 3-4

### API pre-verification

Before writing ANY test code, verify the functions you'll call actually exist with the signatures you assume:

```
# Check function exists and signature
cargo doc --document-private-items -p ithmb-core --no-deps 2>&1 | grep "fn encode_rgb555"
# OR just grep the source
grep "pub fn decode_with_profile" src/pipeline.rs
```

Common trap: `decode_ithmb(src, canceled)` does a profile DB lookup by prefix. For tests with synthetic prefixes, use `decode_with_profile(src, profile, canceled)` instead. Always verify which variant you need.

### Lossy format roundtripping

**The cardinal sin**: Writing `encode_bgra(&profile, &input_bgra).unwrap()` then asserting `decoded == input_bgra`. For lossy formats (RGB565, YCbCr420, ReorderedRGB555), encode→decode is NOT identity.

**The fix**: Compute expected output by roundtripping at fixture setup time:

```rust
fn make_fixture(input_bgra: Vec<u8>, profile: &Profile) -> (Vec<u8>, Vec<u8>) {
    let encoded = encode_bgra(profile, &input_bgra).unwrap();
    let decoded = decode_with_profile(&encoded, profile, &AtomicBool::new(false)).unwrap();
    let expected_bgra = decoded.into_bgra();  // roundtrip is ground truth
    (encoded, expected_bgra)  // test asserts decode(encoded) == expected_bgra
}
```

This works for BOTH lossless and lossy formats — the encode→decode roundtrip defines the expected output.

### Cancellation testing pattern

For cancellation tests with `AtomicBool`:
- Small images (e.g. 2×2) may decode BEFORE the cancellation flag is polled
- Always accept BOTH `Ok` and `Err(DecodeError::Canceled(..))` as valid results
- Use `thread::scope` + `Barrier` for synchronized multi-threaded cancellation
- The cancellation polling checkpoints are at macroblock boundaries in decoders — very small images may never hit one

### Rust 2024 Edition Issues

- **`gen` is reserved** — `let x: u8 = rng.gen()` fails in Rust 2024. Use `rng.random()` or `rng.gen_range(0..256)` instead. `rand 0.8` does NOT have `random()` on `StdRng` — upgrade to `rand 0.9` or use `thread_rng().gen()` in `#[cfg(test)]` where edition 2021 may be active.
- **`.flatten()` type inference** — `.flat_map(|i| vec![...].into_iter()).flatten()` may fail to infer `{integer}`. Fix: annotate `vec![0u8; N]` or use explicit `Vec::with_capacity(N)` + `.push()`.
- **`move` closures in loops** — If you iterate over non-Copy values and `move` them into a closure, the second iteration fails. Fix: wrap in `Arc<T>` or restructure.

### Common function signature pitfalls (ithmb-core specific)

| Assumed | Actual | Fix |
|---------|--------|-----|
| `decode_ithmb(buf, canceled)` | takes profile DB lookup by prefix | Use `decode_with_profile(buf, &profile, canceled)` for test profiles |
| `encode_uyvy(w, h, bgra)` | takes `(w, h, bgra)` only (no extra param) | Remove extra args |
| `encode_rgb555(w, h, bgra)` | takes 5th param `swap_rgb: bool` | Add `false` for standard order |
| `Encoding::Uyvy` | is `Encoding::Yuv422` | Use correct enum variant |
| `Encoding::Clcl` / `Encoding::Cl` | not in pipeline dispatch at all | Use separate `clcl`/`cl` module functions |
| `encoded_image: Vec<u8>` | `roundtrip_once` takes `&[u8]` | Pass `&encoded` not `encoded` |
| `expected_bgra: Vec<Vec<u8>>` | `assert_eq!` debug trait on Vec<Vec<u8>> is verbose | Flatten to `[u8]` or compare element-by-element |

### Workspace-level gotchas

- **`unused_crate_dependencies`** — workspace lint fires on any crate not used by EVERY workspace member. If a dependency is used only by one crate, add it to THAT crate's `Cargo.toml` (not workspace), or add `#[allow(unused_crate_dependencies)]` in test modules.
- **`unsafe_code = "deny"`** — workspace lint denies all `unsafe`. SIMD module works via `#[allow(unsafe_code)]` on individual functions. New `unsafe` blocks need the same treatment.
- **`pedantic = "deny"`** — all pedantic lints are errors. `cargo clippy --fix` handles most mechanical ones.
