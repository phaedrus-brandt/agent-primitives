# Briefing — HTML triage artifact spec

Reference for the brief step. The briefing is one self-contained HTML file — `~/.config/ranger/runs/<date>/report.html` — built to the "Coverage Spine" design (reference implementation: patrol #1's design-22). Present the file path and the lead sentence in chat; the artifact carries everything else.

## Hard rules

- **Every claim traces to a finding id.** A number, a trend, a warning — if no finding carries it, it does not appear.
- **Coverage is legible by design, not copy.** The reader must see how the whole board decomposes without a paragraph explaining it.
- **Humble register.** Ranger assists experts; it never commands. "Worth a look first", "may already be done" — never "Triage these first", never bare imperatives outside the suggested-action text itself.
- **New findings lead; carried findings get one row; a clean patrol renders the spine and one sentence.** Re-raised findings state the dismissal date and what changed.
- **Self-contained and offline.** Inline CSS/JS, system font stacks, zero external requests — card data never calls a CDN, tracker, or font host.
- **Nothing requires punching out.** Full card content (description, repro, acceptance criteria, assignee, filed-by, iteration, tags, comments) renders inline. ADO links (`https://dev.azure.com/BrandtInfoServices/Itinio%20Software%20Development/_workitems/edit/<id>`, new tab) are secondary affordances on every card id.

## Structure, top to bottom

1. **Header** — patrol title + date, lead sentence (truncating, full text in `title`), live decided/remaining stats, Browse|Focus switch (sliding indicator, key `v`), "Copy session summary" (plain-text ACCEPTED/DISMISSED digest of the session's verdicts — the text that feeds back into `memory.jsonl`).
2. **Coverage spine** — the signature element: one segmented horizontal bar decomposing every open item on the board, segments proportional and labeled with counts, summing exactly to the open total. Segments are interactive: the findings segment focuses the table; inventory segments open a searchable drawer listing their cards. A bracket names the scanned set; a callout names the findings count.
3. **Toolbar** — search, kind chips with live counts, Undecided/Decided/All segment, sort (confidence / created / cards touched / kind, asc-desc), collapse-all. All combinable; counts stay truthful.
4. **Findings table** — grouped under sticky collapsible headers with humble one-line group descriptions. Row anatomy: quiet chip, mono id, sans one-line summary, mono confidence/created. Mono ONLY for ids, dates, counts. Cohort rows carry a `+N` member badge.
5. **Peek panel** (row click / Enter) — full evidence, suggested action, and per-card inline expansion with the full card record and comment thread. Action footer (see below).
6. **Focus view** (`v`) — the same queue one finding at a time: full-detail centered card, thin progress rail, same action footer; ends in a session receipt.
7. **Footer strip** — patrol metadata and finding totals by kind.

## Action footer (peek + focus share one component)

Primary button `Accept — <start of suggested action>…` (full text in `title`), quiet Dismiss and Skip, contextual Undo, right-aligned `<kbd>` hints. Decisions persist to localStorage (`{findingId: {status, at}}`); undo everywhere; reload restores.

## Keyboard contract

`j/k` move · `Enter` peek · `Esc` close/back · `a` accept · `d` dismiss · `s` skip · `u` undo · `v` toggle view. Keyboard actions are always instant — animation never rides a keystroke.

## Design tokens

Light surface (`#FFFFFF` cards on `#FAFAFB`), hairline borders `#E6E8EB`, ink `#1A1F36` / secondary `#6A7383` (≥4.5:1 verified), ONE indigo accent `#5E6AD2` for selection and primary actions, amber reserved for the urgency lane, green only for accepted. Lucide-style inline SVG icons (24×24, `stroke=currentColor`, width 2, round caps) — external-link on card ids, check/x/skip-forward on actions. 13–14px UI text, 8px grid, 6px radii, layered soft shadow on floating surfaces only.

## Motion

Purposeful and pointer-gated: one-time staggered reveal on first paint, checkmark draw on pointer-accept, count transitions, 200ms `cubic-bezier(0.23,1,0.32,1)` panel slide, `scale(0.98)` press on pressables. Under 300ms everywhere. `prefers-reduced-motion` disables all of it.

## Register

Simplified Technical English: verb-first, one instruction per sentence, condition before instruction, same name for the same thing, concrete numbers and dates ("23 cards", "created 2025-01-14" — the ADO UI hides created dates, so the artifact always shows them). Hedges only where uncertainty is real, attached to the specific claim. The reader decides; the artifact informs.
