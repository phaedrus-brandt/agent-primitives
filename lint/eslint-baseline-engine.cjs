/**
 * Canonical ESLint baseline RATCHET engine.
 * Canonical source: agent-primitives/lint/eslint-baseline-engine.cjs
 * Vendored into repos as scripts/eslint-baseline-engine.cjs; keep byte-identical.
 *
 * Snapshots every current violation of a chosen set of ESLint rules into a
 * baseline JSON, then on subsequent runs FAILS if a violation isn't in the
 * baseline. Existing hits are grandfathered; new drift is blocked. The
 * backlog can only shrink — fixing a violation just drops it from the next
 * `--write`. This is the shared engine behind every "warn + baseline
 * ratchet" custom-ESLint gate in this repo family (a11y / design-system /
 * timezone / …) — a repo-local ~10-line adapter script supplies the
 * per-ratchet config (baseline path, rule IDs, eslint invocation, keying)
 * and calls `run(config)`.
 *
 * Entries are keyed by file + ruleId + (messageId OR message, per
 * `keyField`) + source line (NOT line/column), so edits elsewhere in a file
 * don't churn the baseline; an `occurrence` counter disambiguates identical
 * violations on identical source lines.
 *
 * `keyField: "messageId"` (the default) is the right choice whenever a
 * rule's rendered message embeds derived/regenerable text (e.g. a
 * design-token suggestion) — keying on the STABLE messageId means a routine
 * regeneration of that derived text doesn't spuriously fail the ratchet.
 * `keyField: "message"` is for rules with no messageId variation, or where
 * historical baseline entries were keyed that way (changing it would be a
 * one-time re-keying of every existing entry, not a behavior change, but
 * ISN'T done implicitly — a caller must opt in explicitly per baseline).
 *
 * `failOnStale: true` additionally fails when a PREVIOUSLY baselined
 * violation no longer occurs — use this for ratchets where the baseline
 * must be actively pruned as debt is paid down (rather than silently
 * carrying dead entries forever); the fix is always `--write`.
 *
 * config = {
 *   baselinePath,        // string — path to baseline JSON, relative to cwd
 *   ruleIds,             // string[] — eslint ruleIds included in this ratchet
 *   eslintArgs,          // string[] — args passed to `node <eslintBin> ...eslintArgs`
 *                         // (target path, --format, cache flags, etc. — whatever
 *                         // this repo's other eslint invocations already use)
 *   keyField,            // "messageId" (default) | "message"
 *   failOnStale,         // boolean, default false
 *   label,               // string — human label for console output, e.g. "Design-lint"
 *   fixHint,             // string — appended to the "new violations" failure output
 *   writeCommandHint,    // string — e.g. "pnpm run tz:baseline:write" (shown on a
 *                         // missing baseline, and on stale entries when failOnStale)
 * }
 *
 * Entry point: `node <adapter>.mjs` (check, the CI gate) / `node <adapter>.mjs --write`
 * (regenerate the snapshot).
 */
const { spawnSync } = require("node:child_process");
const { relative } = require("node:path");
const { existsSync, readFileSync, writeFileSync } = require("node:fs");

// ESLint's JS entrypoint, run with the current Node executable rather than the
// ./node_modules/.bin/eslint shim. The shim is extensionless and not directly
// executable by spawnSync on Windows (the real launcher is eslint.CMD), which
// otherwise fails with `spawnSync ./node_modules/.bin/eslint ENOENT`. This form is
// platform-agnostic and needs no shell.
const ESLINT_BIN = "node_modules/eslint/bin/eslint.js";

function runEslint(eslintArgs) {
  // spawnSync(node, <missing-file>) does NOT set result.error — Node launches and
  // then exits non-zero with "Cannot find module". So detect an absent install
  // explicitly to preserve the loud failure (rather than silently treating empty
  // stdout as "no findings").
  if (!existsSync(ESLINT_BIN)) {
    throw new Error(`Failed to run ESLint: ${ESLINT_BIN} not found.`);
  }

  const result = spawnSync(process.execPath, [ESLINT_BIN, ...eslintArgs], {
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });

  if (result.error) {
    throw new Error(`Failed to run ESLint: ${result.error.message}`);
  }
  if (result.status === null) {
    throw new Error("Failed to run ESLint: process exited without a status.");
  }
  if (result.status && result.status > 1) {
    throw new Error(result.stderr || result.stdout || "ESLint failed");
  }

  return JSON.parse(result.stdout || "[]");
}

function sourceLine(filePath, line) {
  return readFileSync(filePath, "utf8").split(/\r?\n/u)[line - 1]?.trim() || "";
}

function makeKeyFns(keyField) {
  function baseKey(entry) {
    return `${entry.file}:${entry.ruleId}:${entry[keyField]}:${entry.source}`;
  }
  function key(entry) {
    return `${baseKey(entry)}:${entry.occurrence || 1}`;
  }
  return { baseKey, key };
}

function collectEntries(results, ruleIds, keyField) {
  const rules = new Set(ruleIds);
  const { baseKey } = makeKeyFns(keyField);

  const entries = results
    .flatMap((fileResult) =>
      fileResult.messages
        .filter((message) => rules.has(message.ruleId))
        .map((message) => ({
          // Normalize to POSIX separators so the committed baseline is portable
          // across OSes (ESLint reports native paths).
          file: relative(process.cwd(), fileResult.filePath).replaceAll("\\", "/"),
          line: message.line,
          column: message.column,
          ruleId: message.ruleId,
          messageId: message.messageId, // stable identity option; see keyField
          message: message.message, // stable identity option; always human-readable
          source: sourceLine(fileResult.filePath, message.line),
        })),
    )
    .sort(
      (a, b) =>
        baseKey(a).localeCompare(baseKey(b)) || a.line - b.line || a.column - b.column,
    );

  const seen = new Map();
  return entries.map((entry) => {
    const entryBaseKey = baseKey(entry);
    const occurrence = (seen.get(entryBaseKey) || 0) + 1;
    seen.set(entryBaseKey, occurrence);
    return { ...entry, occurrence };
  });
}

function writeBaseline({ baselinePath, ruleIds, entries, label }) {
  writeFileSync(
    baselinePath,
    `${JSON.stringify({ rules: [...ruleIds].sort(), entries }, null, 2)}\n`,
  );
  console.log(`Wrote ${entries.length} ${label} baseline entries.`);
}

function formatEntry(entry) {
  return `- ${entry.file}:${entry.line}:${entry.column} ${entry.ruleId} ${entry.message}`;
}

function checkBaseline({ baselinePath, entries, keyField, failOnStale, label, fixHint, writeCommandHint }) {
  const { key } = makeKeyFns(keyField);

  let baseline;
  try {
    baseline = JSON.parse(readFileSync(baselinePath, "utf8"));
  } catch {
    console.error(`Missing ${baselinePath}. Run \`${writeCommandHint}\` to create it.`);
    process.exit(1);
  }

  const allowed = new Set(baseline.entries.map(key));
  const newEntries = entries.filter((entry) => !allowed.has(key(entry)));

  if (newEntries.length > 0) {
    console.error(`New ${label} violations detected:`);
    for (const entry of newEntries) {
      console.error(formatEntry(entry));
    }
    if (fixHint) console.error(`\n${fixHint}`);
    process.exit(1);
  }

  if (failOnStale) {
    const current = new Set(entries.map(key));
    const staleEntries = baseline.entries.filter((entry) => !current.has(key(entry)));
    if (staleEntries.length > 0) {
      console.error(`Stale ${label} baseline entries detected:`);
      for (const entry of staleEntries) {
        console.error(formatEntry(entry));
      }
      console.error(`\nRun: ${writeCommandHint}`);
      process.exit(1);
    }
  }

  console.log(`${label} baseline passed (${entries.length} current entries).`);
}

function run(config) {
  const {
    baselinePath,
    ruleIds,
    eslintArgs,
    keyField = "messageId",
    failOnStale = false,
    label = "lint",
    fixHint = "",
    writeCommandHint = "",
  } = config;

  const entries = collectEntries(runEslint(eslintArgs), ruleIds, keyField);

  if (process.argv.includes("--write")) {
    writeBaseline({ baselinePath, ruleIds, entries, label });
  } else {
    checkBaseline({ baselinePath, entries, keyField, failOnStale, label, fixHint, writeCommandHint });
  }
}

module.exports = { run };
