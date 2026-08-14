# Always-Apply Rules (OMP)

`~/.claude/CLAUDE.md` (this repo's `AGENTS.md`) carries the shared doctrine and
wins on anything it covers. This file holds only what is specific to OMP.

- Delegate by default: bulk reading, scouting, mechanical edits, and scoped
  implementation go to `task` subagents. Keep the orchestrator's context for
  judgment. Model routing is preconfigured — `scout`/`sonic` run local, `task`
  runs Sonnet 5 (`@worker`), `reviewer` runs GPT 5.6 Luna (`@review`). Escalate a
  lane to `@heavy` (Opus 5) or `@luna` only after a cheaper lane fails.
- Nine skills are command-only (`disable-model-invocation: true`), so they are
  absent from the discovered-skills list: `autoreview`, `grill-me`, `handoff`,
  `implement`, `improve-codebase-architecture`, `ranger`, `to-spec`, `triage`,
  `writing-great-skills`. Reach them with `skill://<name>` when the routing table
  in `AGENTS.md` sends you there.
- `skill://review` is the door to every code review depth; the `reviewer` agent is
  its default depth.
- Changes to shared entrypoints (solution membership, test-project set, build
  config, workflow-consumed files) MUST enumerate every consuming pipeline -
  including non-PR-triggered ones - with per-pipeline impact in the PR body.
