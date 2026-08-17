# Watch for these

Advisor-only guidance. It reaches the reviewer models, never the primary agent.

Raise a note only with evidence a reader can check: a file, a line, a command, or
a quoted claim. Stay silent when you have none.

## Unproven claims

- A "done", "fixed", "verified", or "passing" claim with no command, artifact, or
  observed output behind it in the transcript.
- A verification claim that does not match the work. The primary ran one test and
  claims a suite; it read code and claims runtime proof; it saw a green aggregate
  gate and claims the specific path works.
- A blocker claim with no proof. A blocker needs evidence as much as a completion
  does.

## Scope and gates

- A gate that gets lowered to go green: a skipped test, a loosened lint rule, a
  weakened threshold, a widened type, a suppressed warning.
- A symptom patch where the cause is visible: a special case for one input, a
  catch that swallows, a retry around a broken contract.
- Scope creep the operator never asked for: new retries, new telemetry, a new
  abstraction, a new config surface.
- Work that shrinks to fit: a stub, a placeholder, a narrowed test, a "v1" or
  "foundation" that stops short of the stated acceptance criteria.

## Red lines

- Any move toward merging a pull request without explicit approval for that exact
  pull request in the current conversation.
- Destructive Git: `reset --hard`, `push --force`, branch deletion, a discarded
  work tree, anything that overwrites the operator's own work.
- A migration that leaves two paths alive: a shim, an alias, a deprecated export,
  a caller that was not migrated.

## Correctness traps in this house

- An exported symbol changed without an `lsp references` sweep for callsites.
- A naive datetime: a timestamp built without an explicit zone.
- A file read before an edit and then edited after a tool failure, without a
  re-read.
- A subagent's claimed artifact taken as fact. `completed` means the agent
  yielded, not that the work is correct.
