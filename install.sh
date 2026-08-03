#!/usr/bin/env bash
# Symlink agent primitives into every harness on this machine.
# Idempotent: re-run after adding/removing skills or agents.
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

link() { ln -sfn "$1" "$2"; echo "  $2 -> $1"; }

echo "skills:"
mkdir -p ~/.claude/skills ~/.codex/skills
for d in "$REPO"/skills/*/; do
  name="$(basename "$d")"
  # ~/.claude/skills serves both Claude Code and OMP (OMP discovers .claude at priority 80)
  link "${d%/}" ~/.claude/skills/"$name"
  link "${d%/}" ~/.codex/skills/"$name"
done

# Prune skill symlinks that point back into this repo but no longer resolve
for base in ~/.claude/skills ~/.codex/skills; do
  find "$base" -maxdepth 1 -type l | while read -r l; do
    t="$(readlink "$l")"
    case "$t" in "$REPO"/*) [ -e "$l" ] || { rm "$l"; echo "  pruned $l"; };; esac
  done
done

echo "doctrine:"
link "$REPO/AGENTS.md" ~/.claude/CLAUDE.md   # Claude Code + OMP
link "$REPO/AGENTS.md" ~/.codex/AGENTS.md    # Codex
link "$REPO/RULES.md" ~/.omp/agent/RULES.md  # OMP always-apply rule

echo "mcp:"
mkdir -p ~/.omp/agent
link "$REPO/mcp/mcp.json" ~/.omp/agent/mcp.json
echo "  (claude: apollo lives in ~/.claude.json user scope; codex: in ~/.codex/config.toml)"

echo "agents:"
mkdir -p ~/.claude/agents ~/.omp/agent/agents
for f in "$REPO"/agents/claude/*.md; do link "$f" ~/.claude/agents/"$(basename "$f")"; done
for f in "$REPO"/agents/omp/*.md; do link "$f" ~/.omp/agent/agents/"$(basename "$f")"; done

echo "done."
