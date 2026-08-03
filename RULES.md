# Always-Apply Rules (OMP)

- Delegate by default: bulk reading, scouting, mechanical edits, and scoped
  implementation go to `task` subagents. Keep the orchestrator's context for
  judgment. Model routing is preconfigured — `scout`/`sonic` run local,
  `task` runs Sonnet 5 (`@worker`), `reviewer` runs GPT 5.6 Luna (`@review`).
  Escalate a lane to `@heavy` (Opus 5) or `@luna` only after a cheaper lane
  fails.
- Non-trivial diffs get a cross-family review pass (`reviewer` agent) before
  you call them done.
- Human-facing prose follows `skill://comms`: answer first, plain words, the
  same name for the same thing.
- Habitat (`apollo` MCP) is the work ledger of record.
