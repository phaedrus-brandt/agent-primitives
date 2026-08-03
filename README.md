# agent-primitives

The single source of truth for agent configuration on this machine: skills,
shared doctrine, MCP servers, and subagent identities. `./install.sh`
symlinks everything into each harness (OMP, Claude Code, Codex).

## Layout

- `AGENTS.md` — shared operating doctrine → `~/.claude/CLAUDE.md` (Claude Code
  + OMP), `~/.codex/AGENTS.md` (Codex)
- `RULES.md` — OMP always-apply rule → `~/.omp/agent/RULES.md`
- `skills/` — curated skills → `~/.claude/skills/*` (Claude Code + OMP) and
  `~/.codex/skills/*` (Codex)
- `mcp/mcp.json` — MCP servers (Habitat/apollo) → `~/.omp/agent/mcp.json`.
  Claude Code carries apollo in `~/.claude.json` (user scope); Codex in
  `~/.codex/config.toml`.
- `agents/claude/` — Claude Code subagents (worker/scout/critic) →
  `~/.claude/agents/`
- `agents/omp/` — OMP task agents (heavy) → `~/.omp/agent/agents/`. Bundled
  OMP agents (task/scout/sonic/reviewer) are model-routed via
  `~/.omp/agent/config.yml` `modelRoles` + `task.agentModelOverrides`.

## Skill provenance

- `comms` — authored here. Human-facing writing style: message shape from
  [ayghri/i-have-adhd](https://github.com/ayghri/i-have-adhd) (MIT), sentence
  mechanics from ASD-STE100, word choice from Orwell's six rules.
- `system-recap` — adapted here from
  [kentcdodds/kcd-skills](https://github.com/kentcdodds/kcd-skills) (MIT):
  PR-description system recap with composes/extends/adds classification.
  Block format kept ingestion-compatible with upstream. Do not overwrite on
  refresh.
- `thermo-nuclear-code-quality-review`, `verify-this`, `run-smoke-tests`,
  `check-compiler-errors` — Cursor's official skills from
  [cursor/plugins `cursor-team-kit/skills`](https://github.com/cursor/plugins/tree/main/cursor-team-kit/skills).
- Everything else — [mattpocock/skills](https://github.com/mattpocock/skills)
  (MIT): engineering set (tdd, code-review, diagnosing-bugs, implement,
  research, triage, to-spec, domain-modeling, codebase-design,
  resolving-merge-conflicts) + productivity set (grill-me, grilling, handoff,
  writing-great-skills).

To refresh vendored skills, re-clone the upstream repos and copy the skill
directories over. Names are the dedup key across harnesses. Do not overwrite
`comms` on refresh — it is ours.

## Model policy (see `~/.omp/agent/config.yml`)

Orchestrator pattern, token-savvy: frontier Anthropic drives judgment.
Subagents run on Sonnet 5 (worker), GPT 5.6 Luna xhigh (review/heavy
alternative), Opus 5 (heavy), and local Ollama models (scout/sonic lanes).
When Anthropic or OpenAI hit usage limits or provider errors,
`retry.fallbackChains` drops the turn onto local Ollama models and reverts
when the cooldown expires. The Apollo API key lives in the macOS keychain
(`security find-generic-password -s apollo-api-key`), resolved by OMP's
`!command` env indirection — never in git.
