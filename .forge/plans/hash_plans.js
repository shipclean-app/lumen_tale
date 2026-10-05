#!/usr/bin/env node
/**
 * Write `content_hash` for every slice and foundation from Forge's OWN
 * contentHash(), which hashes the front-matter-stripped, normalised body.
 *
 * Reimplementing that normalisation in Python is how you get 38 files that
 * all report as drifted while looking correct — which is exactly what
 * happened on the first attempt at this. The function is exported by
 * forge-lib, so call it rather than guess at it.
 *
 * Writes only `content_hash` and `plan_path` / `plan_hash`. It does NOT use
 * `state.js register`, which replaces a node's whole entry and dropped
 * `depends_on`, `rule_ids` and `impl_wave` when tried.
 */
const fs = require('fs');
const path = require('path');

const ROOT = '/workspaces/lumen_tale';
const FORGE = '/home/codespace/.agents/skills/forge';
const L = require(path.join(FORGE, 'scripts/lib/forge-lib.js'));

const statePath = path.join(ROOT, '.forge/state.json');
const state = JSON.parse(fs.readFileSync(statePath, 'utf8'));

let hashed = 0;
const missing = [];

for (const kind of ['slices', 'foundations']) {
  for (const [key, entry] of Object.entries(state[kind] || {})) {
    const plan = path.join(ROOT, '.forge/plans', `${key}.md`);
    if (!fs.existsSync(plan)) {
      missing.push(`${kind}/${key}`);
      continue;
    }
    entry.plan_path = `.forge/plans/${key}.md`;
    entry.content_hash = L.contentHash(plan);
    // path stays .forge/architecture.md: that is where the slice is DESCRIBED.
    // plan_path is where it is IMPLEMENTED. state.js set-status reads
    // `path || plan_path`, so both must exist and they must not be conflated.
    hashed += 1;
  }
}

fs.writeFileSync(statePath, JSON.stringify(state, null, 2) + '\n', 'utf8');
console.log(`${hashed} node(s) hashed via forge-lib contentHash`);
if (missing.length) console.log(`missing plans: ${missing.join(', ')}`);
