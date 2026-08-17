# Upstreams

How this repo takes from other people's repos. The rule: **reference and
cherry-pick, never adopt an installer.** Another repo's installer encodes another
machine's model roster, harness set, and file layout. We take the ideas and the
prose; we keep our own wiring.

Every upstream gets a pinned commit here. To refresh one, re-clone at a newer
commit, `diff` against our copy, and take only what still fits. Update the pin.

| Upstream | Pinned at | What we take |
|---|---|---|
| [mattpocock/skills](https://github.com/mattpocock/skills) | `main`, 2026-08-14 | The engineering and productivity skill sets. See README provenance. |
| [anthropics/skills](https://github.com/anthropics/skills) | `main`, 2026-08-14 | `frontend-design`, verbatim, with its LICENSE. |
| [cursor/plugins](https://github.com/cursor/plugins) | `cursor-team-kit/skills` | `verify-this`, `run-smoke-tests`, `check-compiler-errors`, and the thermo rubric now in `skills/review/THERMO.md`. |
| [openclaw/agent-skills](https://github.com/openclaw/agent-skills) | see `skills/autoreview/.vendored-from` | `autoreview`, with its `scripts/autoreview` engine. |
| [kentcdodds/kcd-skills](https://github.com/kentcdodds/kcd-skills) | — | `system-recap`, adapted. Block format stays ingestion-compatible. |
| [misty-step/omp-config](https://github.com/misty-step/omp-config) | `e618640` | See below. |

## misty-step/omp-config

A sibling OMP config repo, single-harness (OMP only), installed by copy. Well
written and close enough to our doctrine to be worth mining.

**Taken as skills**, adapted where this machine differs:

| Skill | Adaptation |
|---|---|
| `evidence-packet` | Removed `hunk`/`herdr` steps. Says how it divides work with `verify-this`. |
| `orient` | Verbatim. |
| `tidy` | Interactive diff step now uses `git diff` and `skill://review`. |
| `foundation` | Names our existing controls: the ESLint baseline ratchet in `lint/`, the pre-push gate in `hooks/`, and `install-anti-slop`. |
| `install-anti-slop` | Verbatim, with its oxlint rule tree. |
| `model-research` | Verbatim. |
| `priorities` | Ledger discovery now names Habitat (`apollo` MCP) first. |

**Taken as ideas**, rewritten as ours:

- **The advisor.** Their `WATCHDOG.md`/`WATCHDOG.yml` showed us OMP's advisor
  subsystem, which we were not using at all. Our `omp/WATCHDOG.{md,yml}` is
  written for our red lines and our model roster: a `Correctness` advisor and an
  `Evidence` advisor, both on GPT 5.6 Luna, watching an Anthropic primary.
- **Deletion-first order.** Their ordered rule (challenge, delete, simplify,
  accelerate, automate) replaced our looser "delete before adding" principle in
  `AGENTS.md`.
- **Versioned OMP config.** They install `config.yml` by copy; we symlink
  `omp/config.yml` instead, so OMP's own writes land in git where we can review
  the drift. Their `task.enableLsp: true` was worth taking.

**Rejected, with reasons:**

| Rejected | Why |
|---|---|
| Their `install` script | Copies instead of linking, wipes `$agent_dir/skills`, and installs a model roster and theme built for their machine. |
| Their `code-review` skill | We have one review door, `skills/review/`. A second reviewer skill is the overlap we just removed. |
| `hunk`, `herdr` skills | Neither binary is installed here. A skill for a missing tool is dead prose. |
| `create-task` | Harbor eval-framework scaffolding. Not our workflow. |
| `writing-for-agents` | We have `writing-great-skills`. Same job, one door. |
| `config.yml` model roles, `models.yml`, `themes/ember.json` | Machine-specific: their roster is Gemini, Grok, and DeepSeek; ours is Anthropic, Codex, and local Ollama. |
| `frontend-design`, `grill-me`, `improve-codebase-architecture`, `prototype` | Already vendored here from the original upstreams. |

## Refresh commands

```sh
git clone --depth 1 https://github.com/misty-step/omp-config /tmp/omp-config
diff -ru skills/orient /tmp/omp-config/skills/orient
```
