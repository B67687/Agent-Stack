#!/usr/bin/env node
/**
 * config-schema-check.mjs — validate ~/.omo/omo.jsonc recursively against the
 * INSTALLED oh-my-openagent schema (node_modules/oh-my-openagent/dist/oh-my-opencode.schema.json).
 *
 * Why installed, not upstream: the dev-branch JSON schema is AHEAD of the installed
 * 4.19.4 (it missed the runtime_fallback ghost keys → false negatives). The installed
 * in-package schema matches the installed Zod shapes (findUnknownKeyPaths ground truth).
 *
 * Exit 0 = clean. Exit 1 = unknown keys found (prints them). Exit 2 = schema/config missing.
 */
import { readFileSync, existsSync } from 'node:fs';
import { createRequire } from 'node:module';
import { homedir } from 'node:os';
import path from 'node:path';

const require = createRequire(import.meta.url);
const { parse, printParseErrorCode } = require('jsonc-parser');

const CONFIG_DIR = path.join(homedir(), '.config', 'opencode');
const SCHEMA_PATH = path.join(CONFIG_DIR, 'node_modules', 'oh-my-openagent', 'dist', 'oh-my-opencode.schema.json');
const OMO_PATH = path.join(homedir(), '.omo', 'omo.jsonc');

// ---- load schema ----
if (!existsSync(SCHEMA_PATH)) { console.error(`[config-schema-check] MISSING schema: ${SCHEMA_PATH}`); process.exit(2); }
if (!existsSync(OMO_PATH)) { console.error(`[config-schema-check] MISSING config: ${OMO_PATH}`); process.exit(2); }
const schema = JSON.parse(readFileSync(SCHEMA_PATH, 'utf8'));

// ---- load config ----
const OMO_PATH_ARG = process.argv[2];
const omoPath = OMO_PATH_ARG || OMO_PATH;
if (!existsSync(omoPath)) { console.error(`[config-schema-check] MISSING config: ${omoPath}`); process.exit(2); }
const text = readFileSync(omoPath, 'utf8');
const errors = [];
const config = parse(text, errors, { allowTrailingComma: true });
if (errors.length > 0) {
  console.error(`[config-schema-check] PARSE ERROR in ${omoPath}: ${errors.map(e => printParseErrorCode(e.error) + '@' + e.offset).join(', ')}`);
  process.exit(1);
}

// ---- recursive validation ----
// Walk `config` value against schema node `sch`. Unknown keys reported as paths.
// Rules:
//  - properties present + additionalProperties object → unknown keys are catch-all (recurse into catch-all)
//  - properties present + additionalProperties false/absent → unknown keys are ERRORS
//  - anyOf → union of object-branch properties (a key valid in ANY branch is OK)
const unknownKeys = [];

function isObjectNode(s) { return s && typeof s === 'object' && (s.type === 'object' || s.properties || s.anyOf || s.additionalProperties); }

function allowedKeysOf(sch) {
  // returns { props: Set|null (null = no properties constraint), catchAll: schemaNode|null }
  if (!sch || typeof sch !== 'object') return { props: null, catchAll: null };
  if (sch.anyOf && Array.isArray(sch.anyOf)) {
    // union across object branches
    let union = null; let catchAll = null;
    for (const branch of sch.anyOf) {
      if (branch === true) return { props: null, catchAll: null }; // permissive branch → everything OK
      if (branch === false) continue;
      if (branch.type === 'boolean' || (branch.type && branch.type !== 'object')) { continue; } // scalar branches don't apply to object values — SKIP, not permissive
      if (isObjectNode(branch)) {
        const r = allowedKeysOf(branch);
        if (r.props === null) return r; // any branch permissive → permissive
        union = union || new Set();
        for (const k of r.props) union.add(k);
        if (r.catchAll) catchAll = r.catchAll;
      }
    }
    return { props: union, catchAll };
  }
  const props = sch.properties ? new Set(Object.keys(sch.properties)) : null;
  let catchAll = null;
  if (sch.additionalProperties && typeof sch.additionalProperties === 'object') catchAll = sch.additionalProperties;
  return { props, catchAll };
}

function walk(value, sch, basePath) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) return;
  if (!isObjectNode(sch)) return; // no schema constraint → skip
  const { props, catchAll } = allowedKeysOf(sch);
  if (props === null && !catchAll) return; // fully permissive
  for (const [key, val] of Object.entries(value)) {
    const p = basePath ? `${basePath}.${key}` : key;
    if (props && props.has(key)) {
      const childSch = sch.properties ? sch.properties[key] : undefined;
      if (childSch) walk(val, childSch, p);
    } else if (catchAll) {
      walk(val, catchAll, p); // dynamic key, validate value against catch-all
    } else if (props === null) {
      // no properties listed → permissive
    } else {
      unknownKeys.push(p);
    }
  }
}

// The installed schema's top level == the [opencode] scope keys. Our config nests them under "[opencode]".
// Walk the "[opencode]" subtree as if it were the schema root. Also walk top-level leftovers
// ($schema, _migrations, profiles...) leniently (skip $schema; _migrations is a known meta key).
const scope = config['[opencode]'];
if (scope && typeof scope === 'object') {
  walk(scope, schema, '[opencode]');
} else {
  // fallback: walk config directly against schema
  walk(config, schema, '');
}

// meta keys that never need schema validation
const META = new Set(['$schema', '_migrations', 'legacy_migrations', 'profiles']);
const realUnknown = unknownKeys.filter(k => !META.has(k.split('.').pop()));

if (realUnknown.length > 0) {
  console.error(`[config-schema-check] UNKNOWN KEYS in ${omoPath} (not in installed schema):`);
  for (const k of realUnknown) console.error(`  - ${k}`);
  console.error('Fix: remove/rename these keys. Ground truth = node_modules/oh-my-openagent/dist/oh-my-opencode.schema.json');
  process.exit(1);
}
console.log(`[config-schema-check] CLEAN: all keys in ${omoPath} valid against installed schema`);
process.exit(0);
