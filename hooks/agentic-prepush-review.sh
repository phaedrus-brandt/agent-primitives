#!/bin/sh
# agentic-prepush-review — risk-tiered agentic code review as a pre-push gate.
# Canonical source: agent-primitives/hooks/agentic-prepush-review.sh
# Vendored into repos as scripts/agentic-prepush-review.sh; keep byte-identical.
#
# Called from .husky/pre-push (or core.hooksPath pre-push) with the hook's
# stdin forwarded: lines of "<local ref> <local sha> <remote ref> <remote sha>".
# Every non-deleted ref in the push is reviewed; any blocked ref blocks the push.
#
# Tiers (chosen per ref, from effective diff size x risk-path match):
#   T0 skip     — docs/prose-only or ignored-only diffs
#   T1 quick    — small, low-risk: single engine, P0 findings only
#   T2 standard — medium or any high-risk path: single engine, P0, full rigor
#   T3 thermo   — large, or high-risk AND non-trivial: cross-family panel
#                 (codex+claude) + thermo-nuclear structural rubric, P1
#
# Escape hatches (logged): git push --no-verify | AGENTIC_REVIEW=0 git push
# Force a tier: AGENTIC_REVIEW_TIER=1|2|3   Force base: AGENTIC_REVIEW_BASE=<ref>
# Fail-open by design when the reviewer toolchain is not installed, so
# teammates without the agentic stack are never blocked. Fails CLOSED on
# findings, engine errors, or diff/config errors when the toolchain is present.

set -u

# Worktree-safe: .git may be a gitlink file in linked worktrees.
GITDIR=$(git rev-parse --git-dir 2>/dev/null) || GITDIR=.git

# ---------------------------------------------------------------- environment
[ "${AGENTIC_REVIEW:-1}" = "0" ] && {
    mkdir -p "$GITDIR/agentic-review" 2>/dev/null
    WHO=$(git config user.email | tr -d '\n\r')
    printf '%s bypass AGENTIC_REVIEW=0 by %s\n' "$(date -u +%FT%TZ)" "$WHO" >> "$GITDIR/agentic-review/bypass.log" 2>/dev/null
    echo "agentic-review: bypassed (AGENTIC_REVIEW=0) - logged."
    exit 0
}
if [ -n "${CI:-}" ] && [ "${CI:-}" != "false" ] && [ "${CI:-}" != "0" ]; then
    exit 0  # CI enforces its own gates
fi

AUTOREVIEW=""
for cand in \
    "${AGENTIC_AUTOREVIEW:-}" \
    "$HOME/.claude/skills/autoreview/scripts/autoreview" \
    "$HOME/.agents/skills/autoreview/scripts/autoreview"; do
    [ -n "$cand" ] && [ -f "$cand" ] && AUTOREVIEW="$cand" && break
done
if [ -z "$AUTOREVIEW" ] || ! command -v python3 >/dev/null 2>&1; then
    echo "agentic-review: toolchain not installed (autoreview skill / python3) - skipping."
    echo "agentic-review: install: https://github.com/openclaw/agent-skills (skills/autoreview)"
    exit 0
fi
HAVE_CLAUDE=0; command -v claude >/dev/null 2>&1 && HAVE_CLAUDE=1
HAVE_CODEX=0;  command -v codex  >/dev/null 2>&1 && codex --version >/dev/null 2>&1 && HAVE_CODEX=1
if [ "$HAVE_CLAUDE" = "0" ] && [ "$HAVE_CODEX" = "0" ]; then
    echo "agentic-review: no review engine (claude/codex CLI) on PATH - skipping."
    exit 0
fi
if ! command -v trufflehog >/dev/null 2>&1; then
    echo "agentic-review: trufflehog missing (autoreview fails closed without it) - skipping."
    echo "agentic-review: install: brew install trufflehog"
    exit 0
fi

# --------------------------------------------------------------------- config
# Repo-local risk config: plain-text pathspec lists (git :(glob) syntax works).
#   .agentic-review.conf   sections: [high-risk] [ignore]
CONF=".agentic-review.conf"
section=""; HIGH_RISK=""; IGNORE=""
if [ -f "$CONF" ]; then
    while IFS= read -r line; do
        case "$line" in
            \#*|"") continue ;;
            "[high-risk]") section=hr; continue ;;
            "[ignore]")    section=ig; continue ;;
            "["*)          section=""; continue ;;
        esac
        case "$section" in
            hr) HIGH_RISK="$HIGH_RISK
:(glob)$line" ;;
            ig) IGNORE="$IGNORE
:(exclude,glob)$line" ;;
        esac
    done < "$CONF"
fi
# Built-in ignores on top of repo config (lockfiles, snapshots, generated).
IGNORE="$IGNORE
:(exclude)pnpm-lock.yaml
:(exclude)package-lock.json
:(exclude,glob)**/*.snap
:(exclude,glob)**/*.min.*"

ZERO="0000000000000000000000000000000000000000"
SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
THERMO_PROMPT="$SELF_DIR/review-prompts/thermo.md"
CACHE_DIR="$GITDIR/agentic-review"; mkdir -p "$CACHE_DIR"

# --------------------------------------------------------------- per-ref gate
# review_ref <local_sha> <remote_sha>  -> returns 0 to allow, nonzero to block
review_ref() {
    LOCAL_SHA=$1; REMOTE_SHA=$2

    if [ -n "${AGENTIC_REVIEW_BASE:-}" ]; then
        BASE=$(git rev-parse --verify --quiet "${AGENTIC_REVIEW_BASE}^{commit}") || {
            echo "agentic-review: AGENTIC_REVIEW_BASE '$AGENTIC_REVIEW_BASE' does not resolve - refusing to guess. BLOCKED."
            return 1
        }
    elif [ "$REMOTE_SHA" != "$ZERO" ] && git cat-file -e "$REMOTE_SHA" 2>/dev/null; then
        BASE="$REMOTE_SHA"
    else
        DEFAULT=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
        BASE=$(git merge-base "$DEFAULT" "$LOCAL_SHA" 2>/dev/null) || BASE=""
    fi
    [ -z "$BASE" ] && { echo "agentic-review: cannot determine base for $LOCAL_SHA - skipping ref."; return 0; }
    [ "$BASE" = "$LOCAL_SHA" ] && return 0      # nothing new

    RANGE="$BASE..$LOCAL_SHA"
    # shellcheck disable=SC2086 — pathspecs are newline-separated, set IFS
    OLDIFS=$IFS; IFS='
'
    set -f
    CHANGED=$(git diff --name-only $RANGE -- . $IGNORE 2>&1); DIFF_ST=$?
    LOC=$(git diff --numstat $RANGE -- . $IGNORE 2>/dev/null | awk '{a+=$1+$2} END{print a+0}')
    RISK_HITS=""
    [ -n "$HIGH_RISK" ] && RISK_HITS=$(git diff --name-only $RANGE -- $HIGH_RISK 2>/dev/null)
    set +f
    IFS=$OLDIFS

    if [ "$DIFF_ST" != "0" ]; then
        echo "agentic-review: git diff failed for $RANGE (bad pathspec in .agentic-review.conf?). BLOCKED, not guessed."
        printf '%s\n' "$CHANGED" | head -3
        return 1
    fi
    [ -z "$CHANGED" ] && { echo "agentic-review: only ignored files changed - skipping ref."; return 0; }
    NON_PROSE=$(printf '%s\n' "$CHANGED" | grep -cvE '\.(md|txt|rst)$' || true)
    if [ "$NON_PROSE" = "0" ]; then
        echo "agentic-review: prose-only diff - skipping ref."
        return 0
    fi

    TIER="${AGENTIC_REVIEW_TIER:-}"
    if [ -z "$TIER" ]; then
        if [ -n "$RISK_HITS" ]; then
            if [ "$LOC" -gt 300 ]; then TIER=3; else TIER=2; fi
        elif [ "$LOC" -gt 600 ]; then TIER=3
        elif [ "$LOC" -gt 150 ]; then TIER=2
        else TIER=1
        fi
    fi

    CACHE_KEY="$CACHE_DIR/clean-$LOCAL_SHA-t$TIER"
    if [ -f "$CACHE_KEY" ]; then
        echo "agentic-review: $LOCAL_SHA already reviewed clean at tier $TIER - skipping ref."
        return 0
    fi

    ENGINE_ARGS=""
    case "$TIER" in
        1)  LABEL="T1 quick (P0, single engine)"
            MAXP="P0"
            if [ "$HAVE_CODEX" = "1" ]; then ENGINE_ARGS="--engine codex --codex-speed fast"; else ENGINE_ARGS="--engine claude"; fi
            ;;
        2)  LABEL="T2 standard (P0, single engine, full rigor)"
            MAXP="P0"
            if [ "$HAVE_CODEX" = "1" ]; then ENGINE_ARGS="--engine codex"; else ENGINE_ARGS="--engine claude"; fi
            ;;
        3)  LABEL="T3 thermo (P1, cross-family panel + structural rubric)"
            MAXP="P1"
            if [ "$HAVE_CODEX" = "1" ] && [ "$HAVE_CLAUDE" = "1" ]; then ENGINE_ARGS="--reviewers codex,claude --allow-partial-panel"
            elif [ "$HAVE_CODEX" = "1" ]; then ENGINE_ARGS="--engine codex"
            else ENGINE_ARGS="--engine claude"; fi
            [ -f "$THERMO_PROMPT" ] && ENGINE_ARGS="$ENGINE_ARGS --prompt-file $THERMO_PROMPT"
            ;;
        *)  echo "agentic-review: invalid AGENTIC_REVIEW_TIER '$TIER'. BLOCKED."; return 1 ;;
    esac

    RISK_NOTE=""
    [ -n "$RISK_HITS" ] && RISK_NOTE=" | high-risk paths: $(printf '%s\n' "$RISK_HITS" | head -3 | tr '\n' ' ')..."
    echo "agentic-review: tier $TIER - $LABEL"
    echo "agentic-review: range $RANGE | ${LOC} LOC across $(printf '%s\n' "$CHANGED" | wc -l | tr -d ' ') files$RISK_NOTE"
    [ "$TIER" = "3" ] && echo "agentic-review: T3 can take a while on big diffs - AGENTIC_REVIEW=0 git push to bypass (logged)."

    FINDINGS="${TMPDIR:-/tmp}/agentic-review-$(basename "$(git rev-parse --show-toplevel)")-findings.json"
    # shellcheck disable=SC2086
    python3 "$AUTOREVIEW" --mode branch --base "$BASE" --commit "$LOCAL_SHA" \
        $ENGINE_ARGS --max-priority "$MAXP" \
        --json-output "$FINDINGS"
    STATUS=$?

    if [ "$STATUS" = "0" ]; then
        date -u +%FT%TZ > "$CACHE_KEY"
        echo "agentic-review: clean at tier $TIER - ref allowed."
        return 0
    fi
    echo ""
    echo "agentic-review: BLOCKED - findings or reviewer error (exit $STATUS)."
    echo "agentic-review: findings: $FINDINGS"
    echo "agentic-review: fix and re-push, or bypass once with: AGENTIC_REVIEW=0 git push (logged)."
    return "$STATUS"
}

# ------------------------------------------------------ all refs from stdin
# Capture stdin up front so the engine invocation cannot swallow later ref lines.
REFS=$(cat)
FAIL=0
while read -r _lref lsha _rref rsha; do
    [ -z "${lsha:-}" ] && continue
    [ "$lsha" = "$ZERO" ] && continue          # branch deletion - nothing to review
    review_ref "$lsha" "${rsha:-$ZERO}" </dev/null || { FAIL=$?; break; }
done <<EOF
$REFS
EOF
exit "$FAIL"
