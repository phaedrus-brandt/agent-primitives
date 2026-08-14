---
name: review
description: "The one door for code review. Routes to the right depth: a cross-family subagent for a normal diff, the autoreview engine before ship, a two-axis standards-and-spec review of a branch or PR, and the thermo rubric for a harsh maintainability audit."
---

# Review

One door, four depths. Pick the depth from the situation, run it, then verify each
finding against the real code before you fix anything.

Never review only with yourself. A critic gets the artifact and the acceptance
criteria, never your reasoning trail. Prefer a different model family than the one
that wrote the code.

## Pick the depth

| Situation | Depth | What to run |
|---|---|---|
| A non-trivial diff, before you call the work done | **Subagent** | One `reviewer` subagent (a different model family). Default. |
| Before commit, push, or ship; or the user asks for a Codex, Claude, or second-model review | **Engine** | The `autoreview` helper. Read `skill://autoreview` first. |
| The user asks to review a branch, a PR, or "the changes since X" | **Two axes** | [TWO-AXIS.md](TWO-AXIS.md) |
| The diff is large, touches a high-risk path, or the user asks for a deep or harsh maintainability audit | **Thermo** | [THERMO.md](THERMO.md), on top of any depth above |

Depths stack. Thermo is a rubric, not a separate run: pass it to the engine with
`--prompt-file`, or hand it to the subagent as its brief.

## Rules that hold at every depth

1. Report only what is worth acting on. A finding needs a file, a line, and a
   consequence.
2. Verify every finding in the real code path before you fix it. Review output is
   advice, not fact.
3. Fix the cause at the owner boundary. Do not patch the symptom, and do not
   lower a gate to get green.
4. Stop when the depth you chose returns nothing actionable. Do not run a second
   pass to get a cleaner closing line.
5. A clean review does not prove the product works. Exercise the changed surface
   as well: `skill://verify-this` for a claim, `skill://run-smoke-tests` for a UI.

## Do not double-review

The pre-push hook (`hooks/agentic-prepush-review.sh`, installed with
`./install.sh --hooks <repo>`) already runs the Engine depth by risk tier, and
adds Thermo at tier 3. If the hook passed on the same refs, do not review them
again. Review again only after the code changes.

## Where each piece lives

- **Engine** — `skills/autoreview/`, binary at `scripts/autoreview`. Command-only:
  the user can type it, the model reaches it through this skill.
- **Two axes** — [TWO-AXIS.md](TWO-AXIS.md). Standards and Spec run as parallel
  subagents and are reported side by side, never merged.
- **Thermo** — [THERMO.md](THERMO.md). The single copy of that rubric. The hook
  reads this same file.
