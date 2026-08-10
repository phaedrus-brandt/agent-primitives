/**
 * ESLint rule: no-naive-datetime
 * Canonical source: agent-primitives/lint/no-naive-datetime.core.cjs
 * Vendored into repos as eslint-rules/no-naive-datetime.core.cjs; keep byte-identical.
 * Repo-local wiring (namespace, ESM/CJS re-export shim, RuleTester adapter,
 * `.eslintrc`/flat-config scoping) stays repo-local — only this file is pinned.
 *
 * Bans the exact shape of the "checkout route calling .toLocaleDateString()
 * with no zone" bug class: a raw `Date` built or formatted with no explicit
 * IANA zone, so it silently renders in the CURRENT VIEWER's browser zone
 * instead of the organization's. Intended for repos with a shared
 * timezone-aware formatting module (see that repo's docs/TIMEZONE_HANDLING.md)
 * that every date/time display and capture is meant to go through instead of
 * a raw `Date`/`Intl` call:
 *
 *   - Display: the shared formatter(s) (or `Intl.DateTimeFormat`) MUST be
 *     given an explicit `{ timeZone }`.
 *   - Capture: a picked wall-clock MUST be converted via the shared
 *     org-timezone helper, not `new Date("…T…").toISOString()`.
 *
 * FLAGS:
 *   - `new Date(...)` given ANY argument. Bare `new Date()` (the current
 *     instant — "now") is fine and NOT flagged: it has no string/number to
 *     parse in an ambiguous zone. (`new Date("2026-07-11T11:00")` parsing in
 *     the browser zone is exactly the argumented form this bans.)
 *   - `.toLocaleDateString(...)` / `.toLocaleTimeString(...)` — unambiguously
 *     `Date` methods (no other builtin has them), so always flagged.
 *   - `.toLocaleString(...)` — ALSO exists on `Number`/`Array`/`BigInt`, which
 *     a codebase may call constantly for count/price formatting
 *     (`total.toLocaleString()`). Flagging every call would swamp a baseline
 *     ratchet with non-tz false positives and block legitimate numeric
 *     formatting forever. SCOPE: only flagged when the receiver is
 *     statically known to be a `Date` — a direct `new Date(...)` chain
 *     (`new Date(x).toLocaleString()`) or an identifier whose LEXICALLY
 *     RESOLVED binding (via ESLint's scope manager, so shadowing in a nested
 *     scope is respected) has `new Date(...)` as every one of its write
 *     expressions (initializer + any reassignments) — a variable reassigned
 *     to anything else (`d = 5`) is no longer treated as a Date at any of
 *     its uses, before or after. Receivers typed `Date` through
 *     props/state/other inference are a documented NON-GOAL (this rule has
 *     no type checker); those slip through the same way they did before
 *     this rule existed.
 *   - `Intl.DateTimeFormat(...)` (`new` or bare call) with no *explicit*
 *     `timeZone` — i.e. no options argument, an options object literal
 *     without a `timeZone` property, or a non-literal options argument
 *     (can't prove a zone is present, so treated as missing one).
 *
 * EXCEPT: the tz module's own implementation (where these primitives are
 * legitimately implemented) and test files — enforced by each repo's
 * `.eslintrc`/flat-config file scoping (`excludedFiles`/`ignores`), not by
 * this rule; it has no repo-specific path knowledge.
 *
 * Suppress a genuine exception with the repo's standard inline-disable
 * convention for this rule's registered id (governed by
 * require-suppression-justification where that rule is active).
 */

const AMBIGUOUS_LOCALE_METHODS = new Set([
  "toLocaleDateString",
  "toLocaleTimeString",
]);

function isDateConstruction(node) {
  return (
    node.type === "NewExpression" &&
    node.callee.type === "Identifier" &&
    node.callee.name === "Date"
  );
}

function isIntlDateTimeFormat(node) {
  return (
    (node.type === "NewExpression" || node.type === "CallExpression") &&
    node.callee.type === "MemberExpression" &&
    !node.callee.computed &&
    node.callee.object.type === "Identifier" &&
    node.callee.object.name === "Intl" &&
    node.callee.property.type === "Identifier" &&
    node.callee.property.name === "DateTimeFormat"
  );
}

function propertyKeyName(property) {
  if (property.type !== "Property") return null;
  if (property.key.type === "Identifier") return property.key.name;
  if (property.key.type === "Literal") return String(property.key.value);
  return null;
}

/** True only when the options arg is a literal object with a `timeZone` key. */
function hasExplicitTimeZone(node) {
  const optionsArg = node.arguments[1];
  if (!optionsArg) return false;
  if (optionsArg.type !== "ObjectExpression") return false; // dynamic — can't prove it
  return optionsArg.properties.some(
    (property) => propertyKeyName(property) === "timeZone",
  );
}

/** @type {import('eslint').Rule.RuleModule} */
module.exports = {
  meta: {
    type: "problem",
    docs: {
      description:
        "Ban raw Date construction/formatting with no explicit IANA zone outside the shared timezone module",
    },
    schema: [],
    messages: {
      naiveConstruction:
        "new Date(...) with an argument parses ambiguously in the current viewer's local " +
        "zone (see this repo's docs/TIMEZONE_HANDLING.md). Use the shared timezone-aware " +
        "formatter (display) or the shared org-timezone capture helper instead — or disable " +
        "this line with a justification if this instant is genuinely zone-agnostic.",
      naiveFormat:
        '"{{method}}" renders in the current viewer\'s local zone by default. Use this ' +
        "repo's shared timezone-aware formatter (see docs/TIMEZONE_HANDLING.md) so the time " +
        "reads the same for every viewer.",
      naiveIntlFormat:
        "new Intl.DateTimeFormat(...) with no explicit `timeZone` renders in the current " +
        "viewer's local zone. Pass `{ timeZone: orgTimeZone }` (see docs/TIMEZONE_HANDLING.md) " +
        "or use the shared formatters instead.",
    },
  },

  create(context) {
    const sourceCode = context.sourceCode ?? context.getSourceCode();

    // A variable is a known `Date` only if EVERY write to it (the
    // initializer and any later reassignments) is a `new Date(...)`
    // construction — one non-Date write (`d = 5`) disqualifies it entirely,
    // rather than trying to track control flow before/after the reassignment.
    function isDateVariable(variable) {
      const writes = variable.references.filter(
        (reference) => reference.isWrite() && reference.writeExpr,
      );
      if (writes.length === 0) return false;
      return writes.every((reference) => isDateConstruction(reference.writeExpr));
    }

    // Resolve `node` through the ACTUAL lexical scope chain (so a shadowing
    // `const d = 1;` in a nested function correctly shadows an outer Date
    // `d`), not a flat same-name Set.
    function resolveVariable(node) {
      if (node.type !== "Identifier") return null;
      let scope = sourceCode.getScope(node);
      while (scope) {
        const variable = scope.set.get(node.name);
        if (variable) return variable;
        scope = scope.upper;
      }
      return null;
    }

    function isKnownDateExpression(node) {
      if (isDateConstruction(node)) return true;
      const variable = resolveVariable(node);
      return variable ? isDateVariable(variable) : false;
    }

    return {
      NewExpression(node) {
        if (isDateConstruction(node) && node.arguments.length > 0) {
          context.report({ node, messageId: "naiveConstruction" });
          return;
        }
        if (isIntlDateTimeFormat(node) && !hasExplicitTimeZone(node)) {
          context.report({ node, messageId: "naiveIntlFormat" });
        }
      },

      CallExpression(node) {
        if (isIntlDateTimeFormat(node) && !hasExplicitTimeZone(node)) {
          context.report({ node, messageId: "naiveIntlFormat" });
          return;
        }

        if (node.callee.type !== "MemberExpression" || node.callee.computed) {
          return;
        }
        const method = node.callee.property.name;
        if (AMBIGUOUS_LOCALE_METHODS.has(method)) {
          context.report({ node, messageId: "naiveFormat", data: { method } });
          return;
        }
        if (
          method === "toLocaleString" &&
          isKnownDateExpression(node.callee.object)
        ) {
          context.report({ node, messageId: "naiveFormat", data: { method } });
        }
      },
    };
  },
};
