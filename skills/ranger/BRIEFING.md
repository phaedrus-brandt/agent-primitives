# Briefing — HTML report spec

Reference for the brief step. The briefing is one self-contained HTML file: `~/.config/ranger/runs/<date>/report.html`. Findings are what the PM acts on; the report is how she reads them. Present the file path and the lead sentence in chat; the report carries everything else.

## Hard rules

- **Every claim traces to a finding id.** A number, a trend, a warning — if no finding carries it, it does not appear.
- **New findings lead.** Findings already reported and still open get one row, never a second argument.
- **A clean patrol is one line.** Render the lead sentence and the still-open table; nothing else. Padding a quiet night teaches the reader to skim.
- **Re-raised findings announce themselves.** A finding returning from dismissal states the dismissal date and the change that brought it back.
- **Self-contained and offline.** One file: inline CSS, system fonts, no script needed for reading (a few lines of inline JS for collapse-all is fine). Zero external requests — card data must never call out to a CDN, tracker, or font host.
- **Every card punches out.** Each card id links to `https://dev.azure.com/BrandtInfoServices/Itinio%20Software%20Development/_workitems/edit/<id>`, opening in a new tab.

## Structure, top to bottom

1. **Title band** — full-width near-black band, report title ("Ranger patrol"), date, patrol number. This is the page's signature; keep everything below it quiet.
2. **Lead** — the single most important thing this patrol found, one or two sentences, set large.
3. **Urgency lane** — only when a finding qualifies (priority-anomaly at 0.9+, or a duplicate touching an active-state card). Distinct left border in the accent color; never used elsewhere.
4. **New findings, grouped by kind** — cohorts first, then duplicates, priority anomalies, missing-context, per-card stale. Each finding is a card row: id, one-line summary, confidence, linked card ids with created dates, suggested action. Evidence and drafts sit inside `<details>` blocks, closed by default. Drafts open with "Proposed by Ranger — verify before use".
5. **Long tails as tables** — when one kind exceeds 15 per-card findings, render one sortable-by-column-order table (oldest state change first) inside a `<details>` block that names the count, instead of finding rows.
6. **Still open / Resolved** — one table each, one row per finding: id, summary, first reported (and for resolved: how). Omit an empty section entirely.
7. **Footer strip** — backlog count, Invoices partition count, patrol timestamp, finding totals by kind.

## Design tokens

Grounded in the subject: a park-service patrol report (Unigrid brochure vernacular — the board's world is parks, marinas, campgrounds).

- **Palette:** band `#1A1A18`; paper `#FCFBF8`; ink `#22221F`; forest `#2F5D3A` (accepted/resolved, confidence marks); blaze `#C75000` (urgency lane only); rule gray `#D9D6CE`.
- **Type:** system sans stack for everything; headings in heavy weight with tight tracking; card ids, dates, and counts in the system mono stack. No webfonts.
- **Layout:** single column, max width ~72ch, generous whitespace; thick 3px rules between kind sections, hairline rules between rows. Confidence renders as a small mono figure (`0.95`), not a progress bar.
- **Register:** all copy follows the register rules below. Buttons/links say what they do ("Open #428640").

Responsive to mobile, visible keyboard focus, honors `prefers-reduced-motion` (no motion is the default anyway).

## Register

Simplified Technical English throughout:

- Lead with the verdict or the action; context after, if at all.
- One instruction per sentence, verb first, active voice, present tense. Under 20 words.
- The condition comes before the instruction: "If the pair is a mirror, dismiss."
- The same name for the same thing every time. Card references are `#428640` with the title on first mention only.
- Concrete numbers and dates: "23 cards", "created 2025-01-14" — never "roughly two dozen" or "quite old". Show created dates wherever cards appear; the ADO UI hides them.
- Cut every word that earns nothing. State facts flat. Keep a hedge only when it carries real uncertainty, attached to the specific claim ("the titles match; the descriptions differ — verify before closing").

The reader decides; the report informs. Recommend, give the evidence, stop.
