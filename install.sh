#!/usr/bin/env bash
# Symlink agent primitives into every harness on this machine.
# Idempotent: re-run after adding/removing skills or agents.
#
# Usage:
#   ./install.sh                    install skills/doctrine/mcp/agents (default)
#   ./install.sh --hooks <repo>     install the pre-push review hook into <repo>
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

link() { ln -sfn "$1" "$2"; echo "  $2 -> $1"; }

# --------------------------------------------------------------- --hooks mode
# Opt-in, per-repo pre-push hook install. Never touches the default flow above
# and never sets a global core.hooksPath.
if [ "${1:-}" = "--hooks" ]; then
  target="${2:-}"
  if [ -z "$target" ]; then
    echo "usage: $0 --hooks <repo-path>" >&2
    exit 1
  fi

  gitdir="$(git -C "$target" rev-parse --git-dir 2>/dev/null)" || {
    echo "install.sh: '$target' is not a git work tree" >&2
    exit 1
  }
  case "$gitdir" in
    /*) : ;;
    *) gitdir="$target/$gitdir" ;;
  esac
  gitdir="$(cd "$gitdir" && pwd)"

  # A repo with core.hooksPath (husky and friends) ignores $gitdir/hooks, so
  # install where git will actually look.
  hooks_dir="$(git -C "$target" config --get core.hooksPath || true)"
  if [ -n "$hooks_dir" ]; then
    case "$hooks_dir" in
      /*) : ;;
      *) hooks_dir="$(cd "$target" && pwd)/$hooks_dir" ;;
    esac
  else
    hooks_dir="$gitdir/hooks"
  fi

  hook_src="$REPO/hooks/agentic-prepush-review.sh"
  hook_dst="$hooks_dir/pre-push"
  mkdir -p "$hooks_dir"

  if [ -L "$hook_dst" ] && [ "$(readlink "$hook_dst")" = "$hook_src" ]; then
    echo "hooks: pre-push already installed -> $hook_src"
    exit 0
  fi

  if [ -e "$hook_dst" ] || [ -L "$hook_dst" ]; then
    echo "install.sh: $hook_dst already exists and is not the agent-primitives symlink." >&2
    echo "Current contents:" >&2
    if [ -L "$hook_dst" ]; then
      echo "  symlink -> $(readlink "$hook_dst")" >&2
    else
      sed 's/^/  /' "$hook_dst" >&2
    fi
    echo "To chain both, move the existing hook aside (e.g. pre-push.local) and" >&2
    echo "have it exec \"$hook_src\" \"\$@\" < /dev/stdin as its last step (or the reverse)," >&2
    echo "then re-run: $0 --hooks $target" >&2
    exit 1
  fi

  ln -s "$hook_src" "$hook_dst"
  echo "hooks: installed pre-push -> $hook_src"
  exit 0
fi

echo "skills:"
"$REPO/scripts/check-skills.sh"
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

echo "mcp (generated):"
# mcp/mcp.json is canonical. Codex's config.toml and Claude's ~/.claude.json
# each need the same servers in their own native shape; generate both instead
# of hand-maintaining three copies of the same secret-bearing config.
MCP_JSON="$REPO/mcp/mcp.json"
CODEX_EXTRAS="$REPO/mcp/codex-extras.toml"
CODEX_CONFIG="$HOME/.codex/config.toml"
CLAUDE_JSON="$HOME/.claude.json"
CODEX_BEGIN_MARK="# >>> agent-primitives managed — edits here are overwritten by install.sh"
CODEX_END_MARK="# <<< agent-primitives managed"

# resolve_mcp_env <server> <key> <raw-value> -> resolved value on stdout
# OMP's "!command" indirection: run the rest of the string through sh -c and
# use its trimmed stdout. Abort the whole install on failure or empty output
# so we never write a partial or empty-secret config.
resolve_mcp_env() {
  local server="$1" key="$2" raw="$3" val
  case "$raw" in
    '!'*)
      if ! val="$(sh -c "${raw#!}" 2>/dev/null)"; then
        echo "install.sh: mcp server '$server' env '$key': command failed: ${raw#!}" >&2
        exit 1
      fi
      val="$(printf '%s' "$val" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      if [ -z "$val" ]; then
        echo "install.sh: mcp server '$server' env '$key': command produced empty output: ${raw#!}" >&2
        exit 1
      fi
      ;;
    *)
      val="$raw"
      ;;
  esac
  printf '%s' "$val"
}

SERVER_NAMES="$(jq -r '.mcpServers | keys[]' "$MCP_JSON")"

codex_body=""
claude_tmp="$(mktemp)"
claude_exists=0
[ -f "$CLAUDE_JSON" ] && { claude_exists=1; cp "$CLAUDE_JSON" "$claude_tmp"; }

while IFS= read -r name; do
  [ -n "$name" ] || continue
  server_json="$(jq -c --arg n "$name" '.mcpServers[$n]' "$MCP_JSON")"
  command="$(jq -r '.command' <<<"$server_json")"
  args_json="$(jq -c '.args // []' <<<"$server_json")"

  env_keys="$(jq -r '.env // {} | keys[]' <<<"$server_json")"
  resolved_env='{}'
  if [ -n "$env_keys" ]; then
    while IFS= read -r k; do
      [ -n "$k" ] || continue
      raw="$(jq -r --arg k "$k" '.env[$k]' <<<"$server_json")"
      val="$(resolve_mcp_env "$name" "$k" "$raw")"
      resolved_env="$(jq -c --arg k "$k" --arg v "$val" '. + {($k): $v}' <<<"$resolved_env")"
    done <<<"$env_keys"
  fi

  # Codex TOML stanza
  codex_body+="[mcp_servers.${name}]"$'\n'
  codex_body+="command = $(printf '%s' "$command" | jq -Rs .)"$'\n'
  if [ "$args_json" != "[]" ]; then
    codex_body+="args = $args_json"$'\n'
  fi
  if [ "$resolved_env" != "{}" ]; then
    codex_body+=$'\n'"[mcp_servers.${name}.env]"$'\n'
    while IFS= read -r k; do
      [ -n "$k" ] || continue
      v="$(jq -r --arg k "$k" '.[$k]' <<<"$resolved_env")"
      codex_body+="$k = $(printf '%s' "$v" | jq -Rs .)"$'\n'
    done < <(jq -r 'keys[]' <<<"$resolved_env")
  fi
  codex_body+=$'\n'

  # Claude Code entry
  if [ "$claude_exists" = "1" ]; then
    jq -c --arg name "$name" --arg command "$command" --argjson args "$args_json" --argjson env "$resolved_env" \
      '.mcpServers[$name] = {command: $command, args: $args, env: $env}' \
      "$claude_tmp" > "$claude_tmp.next"
    mv "$claude_tmp.next" "$claude_tmp"
  fi
done <<<"$SERVER_NAMES"

codex_body+="$(cat "$CODEX_EXTRAS")"$'\n'
codex_region="$CODEX_BEGIN_MARK"$'\n'"$codex_body""$CODEX_END_MARK"$'\n'

if [ -f "$CODEX_CONFIG" ]; then
  base="$(mktemp)"
  # 1. strip the existing managed region, if any
  awk -v b="$CODEX_BEGIN_MARK" -v e="$CODEX_END_MARK" '
    $0==b {skip=1; next}
    $0==e {skip=0; next}
    !skip {print}
  ' "$CODEX_CONFIG" > "$base"

  # 2. strip unmanaged duplicate [mcp_servers.<name>...] blocks for names we
  #    now manage, so Codex never sees two definitions of the same server.
  cleaned="$(mktemp)"
  names_pattern="$(printf '%s' "$SERVER_NAMES" | paste -sd '|' -)"
  awk -v names="$names_pattern" '
    BEGIN { n = split(names, arr, "|") }
    {
      line = $0
      is_managed = 0
      if (line ~ /^\[mcp_servers\./) {
        for (i = 1; i <= n; i++) {
          pat = "^\\[mcp_servers\\." arr[i] "(\\.|\\])"
          if (line ~ pat) { is_managed = 1; break }
        }
      }
      if (is_managed) { skip = 1; next }
      if (line ~ /^\[/) { skip = 0 }
      if (skip) next
      print line
    }
  ' "$base" > "$cleaned"
  rm -f "$base"

  # 3. drop trailing blank lines, then append one blank line + the region
  awk 'BEGIN{n=0} {a[n++]=$0} END{while(n>0 && a[n-1]=="") n--; for(i=0;i<n;i++) print a[i]}' "$cleaned" > "$cleaned.trimmed"
  had_content=$(wc -l < "$cleaned.trimmed" | tr -d ' ')
  {
    cat "$cleaned.trimmed"
    [ "$had_content" -gt 0 ] && printf '\n'
    printf '%s' "$codex_region"
  } > "$CODEX_CONFIG.new"
  mv "$CODEX_CONFIG.new" "$CODEX_CONFIG"
  rm -f "$cleaned" "$cleaned.trimmed"
  echo "  ~/.codex/config.toml (managed region)"
else
  echo "install.sh: warning: ~/.codex/config.toml not found, skipping codex mcp generation" >&2
fi

if [ "$claude_exists" = "1" ]; then
  orig_keys="$(jq -S 'keys' "$CLAUDE_JSON")"
  new_keys="$(jq -S 'keys' "$claude_tmp")"
  if [ "$orig_keys" != "$new_keys" ]; then
    echo "install.sh: refusing to write ~/.claude.json: top-level keys changed" >&2
    diff <(echo "$orig_keys") <(echo "$new_keys") >&2 || true
    rm -f "$claude_tmp"
    exit 1
  fi
  jq empty "$claude_tmp"
  [ -f ~/.claude.json.bak-agent-primitives ] || cp "$CLAUDE_JSON" ~/.claude.json.bak-agent-primitives
  mv "$claude_tmp" "$CLAUDE_JSON"
  echo "  ~/.claude.json (mcpServers)"
else
  echo "  ~/.claude.json not found, skipping (warning: Claude Code config not present)"
fi
rm -f "$claude_tmp"

echo "agents:"
mkdir -p ~/.claude/agents ~/.omp/agent/agents
for f in "$REPO"/agents/claude/*.md; do link "$f" ~/.claude/agents/"$(basename "$f")"; done
for f in "$REPO"/agents/omp/*.md; do link "$f" ~/.omp/agent/agents/"$(basename "$f")"; done

echo "done."
