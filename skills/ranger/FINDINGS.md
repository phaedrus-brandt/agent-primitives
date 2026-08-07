# Findings — kinds, gates, contract

Reference for the analyze step. Apply every gate; emit one finding per matched condition. A gate is mechanical: when its conditions hold, the candidate exists — judgment enters only in confidence scoring and drafting.

## Board facts (verified 2026-08-04, live snapshot of 5,087 open items)

These facts shape the gates. Re-verify them if the board's process visibly changes.

- **Mirror pairs are process, not duplicates.** The board deliberately keeps client/internal pairs (`Client Story Work Item` ↔ `User Story`, `Client Bug Work Item` ↔ `Bug`, and the Feature/Epic/Initiative equivalents) with identical titles, linked parent-child. 186 such pairs existed at survey; a 12-pair sample showed all correctly linked. A cross-type pair with matching titles is a duplicate finding only when the link is missing.
- **Template tasks repeat titles by design.** Tasks named "Dev Work", "Run Test Cases", "Testing in UAT", "Dev to Push to CAT" and similar scaffold names recur across parents (194 tasks in 18 title groups at survey). Exclude `Task` from duplicate detection.
- **Test artifacts are out of scope.** `Test Suite`, `Test Case`, `Test Plan`, `Shared Steps` are not groomable backlog. Filter them out after the snapshot.
- **Groomable types:** User Story, Client Story Work Item, Bug, Client Bug Work Item, Task, Feature, Client Feature Work Item, Epic, Client Epic Work Item, Initiative, Client Initiative Work Item, Issue.
- **Active states:** In Progress, Ready for QA, Active, Selected for Development, Ready for Development, Design.
- **Done-like open state:** "Passes QA Testing" is a terminal-in-practice state where finished work accumulates (346 open at survey).
- **The `\Invoices` iteration is a partition, not dev backlog.** Cards under iteration path `Itinio Software Development\Invoices` (149 at survey) are data-cleanup work handled separately. Exclude them from every gate below; report them as one line in the briefing ("Invoices partition: N cards").
- **Tags carry almost no signal.** 134 distinct tags at survey, 54 used once. Ignore tags in every gate, with two exceptions that mark live ranking workflow: `BacklogRanked` and `Needs Rank`.
- **`System.ChangedDate` lies about activity.** Bulk edits (tag sweeps, iteration moves) reset it board-wide: every card 18+ months old showed a "change" within 90 days at survey. Date gates use `Microsoft.VSTS.Common.StateChangeDate`, present on every card.

## Finding contract

```json
{
  "id": "dup-21996-22963",
  "kind": "duplicate | stale | missing-context | priority-anomaly | legacy-consolidation",
  "cards": [21996, 22963],
  "confidence": 0.9,
  "summary": "One sentence: what is wrong.",
  "evidence": ["field-level facts from the snapshot, one per entry"],
  "suggested_action": "One imperative sentence a human can execute.",
  "draft": null,
  "fingerprint": { "per-kind shape below" }
}
```

- `id` = kind prefix + card ids sorted ascending, joined with `-`. Cohort findings are the exception — identified by their condition, not their members, so they survive nightly membership drift: `stale-cohort-<state, lowercased, spaces to dashes>` and `legacy-punchlist`. Deterministic: the same condition yields the same id every patrol.
- `evidence` entries are observations, never inferences: "identical titles", "created 4 minutes apart", "no link between the cards", "unchanged since 2026-05-02". Always include each card's created date — the ADO UI hides it, so the finding must carry it.
- `fingerprint` carries the exact gate inputs the finding rests on, shaped per kind (see each gate). The reconcile step compares a candidate's fingerprint to a stored one **field by field**: any differing field is a material change. Hash long text (sha256 of the tag-stripped body); store everything else verbatim.
- `draft` is null except for missing-context and legacy-consolidation findings.

## Kinds and gates

### duplicate

Candidate gate — all conditions:

1. Same work item type (never `Task`).
2. Titles match after lowercasing and collapsing non-alphanumerics, or differ only by an obvious paraphrase.
3. No link of any type between the cards (per the relations recipe; a failed relations call drops the candidate).
4. The descriptions report the same defect or request. Read both bodies; same title over distinct asks fails the gate. Paraphrase calls (conditions 2 and 4) are the judged part of this gate — they set confidence, and below 0.7 the rubric already discards the finding.

Cross-type exception: a Client/internal pair with matching titles and **no** link is a candidate under conditions 2–4 — its suggested action is "link as parent-child", not "close one".

Suggested action: name which card to keep (the older, or the better-specified) and which to close or link.

Fingerprint: `{"titles": [...], "body_hashes": [...], "linked": false}` — covers conditions 2–4; a dismissed duplicate returns only when a title, a body, or the link state changes.

### stale

Two shapes:

- **Per-card:** state in the active set and no state change in 60+ days (`Microsoft.VSTS.Common.StateChangeDate`). Evidence: state, state-change date, assignee (unassigned strengthens it). Fingerprint: `{"state": "...", "state_change_date": "...", "assignee": "..."}`.
- **Cohort:** 20 or more cards sharing one done-like or intake state (intake states: `Intake - Requirements`, `Intake - Product Review`, `Intake - Tech Scope`) with no state change in 30+ days emit **one** finding listing all card ids. Suggested action is the bulk operation ("review and close the N cards in 'Passes QA Testing' untouched since <date>"), never N per-card findings. Fingerprint: `{"state": "...", "cards": [...], "count": N}` — membership change of 20% or more, or any state change, is material; smaller drift is not.

### missing-context

Gate: type is a story or bug variant, and the combined plain text of Description + Repro Steps + Acceptance Criteria is under 40 characters.

Prioritize cards created in the last 30 days — thin fresh cards are fixable while the filer still remembers; thin old cards rank lower.

For cards created in the last 30 days, fill `draft` with proposed text: acceptance criteria for a story, repro skeleton (steps / expected / actual) for a bug, inferred **only** from the title, comments, and linked cards. Open the draft with `Proposed by Ranger — verify before use:`. When the title alone is too little to draft from, say so in the finding and leave `draft` null — a wrong draft costs the reader more than a flag.

Fingerprint: `{"type": "...", "body_hash": "...", "comment_count": N}` — a body edit or new comments is material.

### priority-anomaly

Gate: title starts with an urgency marker — `!`, `!!`, `**`, `URGENT`, `ASAP`, `CRITICAL` (case-insensitive) — and the Priority field is unset or greater than 1.

Evidence: the exact title, the Priority value, the state. A card both urgent-titled and sitting in New or an intake state ranks highest.

Fingerprint: `{"title": "...", "priority": null, "state": "..."}`.

### legacy-consolidation

Gate: created 18+ months ago, no state change in 90+ days (`Microsoft.VSTS.Common.StateChangeDate`), and state not in the active set. When 20 or more cards match, emit **one** cohort finding, id `legacy-punchlist`, listing all card ids oldest-first.

Fill `draft` with proposed punchlist text: one line per card — id, title, created date — grouped by area or product noun, opening with `Proposed by Ranger — verify before use:`. Suggested action: create one consolidated legacy ticket from the draft, then close the listed cards.

Fingerprint: `{"cards": [...], "count": N}` — membership change of 20% or more is material; smaller drift is not. (158 cards matched at survey.)

## Confidence rubric

- **0.9+** — every gate condition holds on hard fields and a human would agree on sight (identical titles, unlinked, same defect text). Report.
- **0.7–0.9** — gates hold but interpretation was involved (paraphrased titles, drafted context). Report, worded as a question where honest.
- **below 0.7** — do not report. No finding is better than a retracted one.
