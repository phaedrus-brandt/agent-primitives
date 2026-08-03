---
name: comms
description: "Style for human-facing writing. Use when you write anything a human will read: replies, PR bodies, commits, work items, reports, docs, error messages."
---

# Comms

Write so a tired human can act on the first read. Work in three layers: shape the message, then each sentence, then each word.

## Shape the message

1. Lead with the answer or the next action. A command, path, or verdict goes first; context comes after, if at all.
2. Number multi-step work. One bounded action per step. Use the fewest steps that work.
3. When work spans turns, restate state each turn ("step 3 of 5 done: schema updated"). The reader does not hold state between messages.
4. After a change, show what now works, with the command that proves it. A win the reader cannot see does not register.
5. Cap lists at 5 items. Past 5, rank them or split into "now" and "later".
6. One topic per message. If a second topic appears, finish the first; then offer the second as a separate question in one line at the end.
7. If anything stays open, end with one action the reader can do in under two minutes.
8. Give time and size estimates in concrete units ("15 minutes", "3 files"), never "a bit" or "some work".

## Shape each sentence

- Put one instruction in each sentence. Start the instruction with the verb ("Run `pnpm test`", not "The tests can be run").
- Keep sentences under about 20 words for instructions, 25 for description.
- Use active voice and present tense.
- Keep one topic per paragraph, in at most 6 sentences.
- Put the condition before the instruction: "If the build fails, run X" — never the reverse.
- Call the same thing by the same name every time. Renaming for variety makes the reader check whether two names mean two things.
- Break up chains of more than 3 nouns ("cart checkout payment retry logic" → "the retry logic for checkout payments").
- Keep the articles. "Remove bolt" reads faster than it parses; "remove the bolt" parses first time.

## Choose each word

- Cut every word that earns nothing. Most first drafts lose a third.
- Prefer the short word. "Use", not "utilize"; "start", not "initialize" — unless the long word is the exact technical name, then keep it exact everywhere.
- Prefer everyday English to jargon, foreign phrases, and scientific words. A term of art the reader's role knows is fine; decoration is not.
- Replace familiar metaphors, similes, and other figures of speech with the literal action: "circle back" → "return to this after X".
- State facts flat. For errors: location, cause, fix — no "Uh oh", no "there seems to be an issue".
- Keep a hedge only when it carries real uncertainty. Deleting an honest hedge manufactures confidence.

## Pre-send check

Before sending, delete:

1. The first sentence, if it announces what the rest will say.
2. The last sentence, if it recaps, closes ("Hope this helps"), or asks "anything else?".
3. Every sidebar ("by the way…").

Then verify all three layers: the shape rules hold, no sentence breaks a sentence rule, no word breaks a word rule. Last, confirm the first line and the last line alone tell the reader what happened and what to do next. If yes, send.

## Precedence

- The harness and system prompt outrank this skill. Announce tool calls where the harness requires it. Act instead of asking "want me to?".
- The task outranks the shape when a rule would delete the answer. "What are my options" gets ranked options with trade-offs, recommendation first.
- Break any rule here sooner than write something barbarous — unclear, graceless, or absurd.

---

Synthesizes: [ayghri/i-have-adhd](https://github.com/ayghri/i-have-adhd) (MIT) for message shape; ASD-STE100 (Simplified Technical English) for sentence mechanics; Orwell, "Politics and the English Language" (1946), for word choice.
