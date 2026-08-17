# agent-primitives

The single source of truth for agent configuration on this machine: skills,
shared doctrine, MCP servers, and subagent identities. `./install.sh`
symlinks everything into each harness (OMP, Claude Code, Codex).

## Layout

- `AGENTS.md` — shared operating doctrine → `~/.claude/CLAUDE.md` (Claude Code
  + OMP), `~/.codex/AGENTS.md` (Codex)
- `RULES.md` — OMP-only rules → `~/.omp/agent/RULES.md`. Everything shared lives
  in `AGENTS.md`.
- `skills/` — curated skills → `~/.claude/skills/*` (Claude Code + OMP) and
  `~/.codex/skills/*` (Codex). `scripts/check-skills.sh` validates them before
  linking.
- `mcp/mcp.json` — the one MCP definition (Habitat/apollo, azure-devops), plus
  OMP's `disabledServers` denylist → symlinked to `~/.omp/agent/mcp.json`.
  `install.sh` generates the harness copies from it: a managed region in
  `~/.codex/config.toml` (Codex-only extras appended from `mcp/codex-extras.toml`)
  and `.mcpServers` entries in `~/.claude.json`. `!command` env values are
  resolved at install time for harnesses without indirection.
  The denylist hides `node_repl`: Codex declares that server with a command inside
  the ChatGPT/Codex app bundle, OMP discovers Codex's servers, and OMP has its own
  `eval` and `browser` tools. If the app moves again, Codex rewrites the block and
  OMP stays quiet.
- `hooks/agentic-prepush-review.sh` — risk-tiered review gate. Opt in per repo:
  `./install.sh --hooks <repo>`. It loads the thermo rubric from the installed
  `review` skill.
- `agents/claude/` — Claude Code subagents (worker/scout/critic) →
  `~/.claude/agents/`
- `omp/config.yml` — OMP settings, symlinked to `~/.omp/agent/config.yml` so OMP's
  own writes land in git. Carries `modelRoles`, `task.agentModelOverrides`,
  `task.agentAdvisor`, `retry.fallbackChains`, and `advisor.enabled`.
- `omp/WATCHDOG.md`, `omp/WATCHDOG.yml` — the advisor: two GPT 5.6 Luna reviewers
  (`Correctness`, `Evidence`) that watch an Anthropic primary turn by turn and
  inject `<advisory>` notes. `WATCHDOG.md` reaches the advisors only, never the
  primary. `/advisor status` shows their cost; `/advisor off` stops them.
  `task.agentAdvisor` extends the watch to writing subagents and only those:
  `task` gets Luna at medium effort, `sonic` gets the local scout model, `heavy`
  gets Luna at full effort; `scout`, `librarian`, `reviewer`, and
  `security-reviewer` stay unadvised. Measured cost: about 5k input tokens and
  $0.001 per advisor turn.
- `agents/omp/` — OMP task agents (heavy) → `~/.omp/agent/agents/`. Bundled
  OMP agents (task/scout/sonic/reviewer) are model-routed via `omp/config.yml`
  `modelRoles` + `task.agentModelOverrides`.
- `docs/upstreams.md` — every upstream we mine, its pinned commit, what we took,
  and what we rejected. Read it before pulling from another config repo.

## Skill provenance

- `comms` — authored here. Human-facing writing style: message shape from
  [ayghri/i-have-adhd](https://github.com/ayghri/i-have-adhd) (MIT), sentence
  mechanics from ASD-STE100, word choice from Orwell's six rules.
- `system-recap` — adapted here from
  [kentcdodds/kcd-skills](https://github.com/kentcdodds/kcd-skills) (MIT):
  PR-description system recap with composes/extends/adds classification.
  Block format kept ingestion-compatible with upstream. Do not overwrite on
  refresh.
- `review` — assembled here. One auto-invocable door with four depths:
  `reviewer` subagent, the `autoreview` engine, `TWO-AXIS.md` (Pocock's
  `code-review`, standards + spec), and `THERMO.md` (Cursor's
  thermo-nuclear rubric, also loaded by the pre-push hook). It replaces the old
  `code-review` and `thermo-nuclear-code-quality-review` skills and
  `hooks/review-prompts/`.
- `autoreview` — vendored from
  [openclaw/agent-skills](https://github.com/openclaw/agent-skills)
  (see `skills/autoreview/.vendored-from`); carries the `scripts/autoreview`
  engine. Command-only; `review` is its door.
- `verify-this`, `run-smoke-tests`, `check-compiler-errors` — Cursor's official
  skills from
  [cursor/plugins `cursor-team-kit/skills`](https://github.com/cursor/plugins/tree/main/cursor-team-kit/skills).
- `frontend-design` — verbatim from
  [anthropics/skills](https://github.com/anthropics/skills/tree/main/skills/frontend-design)
  (LICENSE.txt kept alongside). OMP also bundles this skill; the repo copy
  shadows it and gives Claude Code + Codex the same version.
- `evidence-packet`, `orient`, `tidy`, `foundation`, `install-anti-slop`,
  `model-research`, `priorities` — from
  [misty-step/omp-config](https://github.com/misty-step/omp-config), adapted.
  `docs/upstreams.md` records each adaptation and what we rejected.
- Everything else — [mattpocock/skills](https://github.com/mattpocock/skills)
  (MIT): engineering set (tdd, diagnosing-bugs, implement, research, triage,
  to-spec, domain-modeling, codebase-design, improve-codebase-architecture,
  prototype, resolving-merge-conflicts) + productivity set (grill-me, grilling,
  handoff, writing-great-skills).

To refresh vendored skills, follow `docs/upstreams.md`: re-clone at a newer
commit, diff against our copy, take what still fits, then move the pin. Names are
the dedup key across harnesses. Do not overwrite `comms` on refresh — it is ours.

## Model policy (see `omp/config.yml`)

Orchestrator pattern, token-savvy: frontier Anthropic drives judgment.
Subagents run on Sonnet 5 (worker), GPT 5.6 Luna xhigh (review/heavy
alternative), Opus 5 (heavy), and local Ollama models (scout/sonic lanes).
When Anthropic or OpenAI hit usage limits or provider errors,
`retry.fallbackChains` drops the turn onto local Ollama models and reverts
when the cooldown expires. The Apollo API key lives in the macOS keychain
(`security find-generic-password -s apollo-api-key`), resolved by OMP's
`!command` env indirection — never in git.
