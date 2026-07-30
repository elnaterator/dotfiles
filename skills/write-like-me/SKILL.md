---
name: write-like-me
description: |
  Drafts and edits prose in the user's personal writing voice. Use this skill when the user asks to:
  - Draft an email, message, doc, PR description, Slack post, or any prose "in my voice" / "so it sounds like me"
  - Rewrite or edit existing text to match their style
  - Ghostwrite something they will send as themselves
  It reads a stored STYLE_PROFILE.md (the user's voice fingerprint) and applies it. If the profile is
  empty or missing, it first walks the user through building one from samples of their real writing.
---

# Write Like Me

Produce prose that reads as though the user wrote it. The voice lives in `STYLE_PROFILE.md` next to this
file. That profile is the source of truth — never invent a voice from assumptions.

## Core principles

1. **Profile first.** Read `STYLE_PROFILE.md` before writing a single line. Every draft is an application
   of that profile, not a generic "professional" default.
2. **Imitate, don't improve.** Match the user's real habits even when they differ from "best practice"
   (e.g. they may prefer no greeting, lowercase, em-dashes, short paragraphs). Do not smooth these out.
3. **Preserve their register per context.** Email to a VP ≠ Slack to a teammate. The profile records how
   the voice shifts by audience and channel — honor that.
4. **Facts over flourish.** Voice matching never justifies inventing details. If content is missing, ask
   or leave a clearly marked `[TODO: ...]` placeholder.
5. **Hand back editable drafts.** Output the draft plainly so the user can tweak and send. Offer 1 short
   note on any judgment call you made, then stop.

## Workflow: drafting or rewriting

1. **Load the profile.** Read `STYLE_PROFILE.md` in this skill directory.
   - If it is still the unfilled template (contains `[FILL:` markers) or missing → jump to
     **Workflow: building the profile** first, then return here.
2. **Gather the ask.** Confirm: what is it (email/doc/PR/Slack/…), who is the audience, what is the goal,
   and any must-include points. Ask only what you genuinely can't infer.
3. **Pick the register.** Match the audience/channel row in the profile.
4. **Draft.** Apply the profile's rules: sentence length, greeting/sign-off habits, vocabulary,
   punctuation quirks, structure, formatting, do's and don'ts.
5. **Self-check against the profile.** Before returning, scan the draft against the "Tells" and "Avoid"
   lists. Fix anything off-voice.
6. **Return the draft** in a code block or plain block the user can copy. Add at most one line flagging
   assumptions or placeholders.

## Workflow: building the profile

Trigger this when the profile is empty, when the user says "update how you write like me," or when a draft
came back off-voice.

1. **Collect samples.** Ask the user to paste 3–8 pieces of their own real writing — ideally a mix:
   a couple of emails, a Slack/chat message, a doc or PR description. More variety = better profile.
   - If they have none handy, fall back to the "Describe my style" prompts in the template and encode
     their answers.
2. **Analyze across dimensions** (see the template's headings). For each, extract concrete, observable
   patterns with short verbatim examples pulled from the samples — not vague adjectives. "Uses em-dashes
   for asides and rarely commas" beats "punchy."
3. **Write the profile.** Fill in `STYLE_PROFILE.md`, replacing every `[FILL: ...]` marker. Keep examples
   short and real. Populate the audience/register table with at least the channels the user actually uses.
4. **Verify.** Draft one short test piece, show it to the user, and adjust the profile from their feedback.
   Voice profiles improve iteratively — treat the first version as a draft.

## Storing samples

Raw samples can be personal. Keep them out of git:
- Put pasted samples in `samples/` inside this skill dir (already gitignored via `samples/.gitignore`).
- The distilled `STYLE_PROFILE.md` is safe to commit if the user wants it versioned; it holds patterns,
  not private content. Ask before committing if unsure.

## Notes

- This skill writes **normal prose** — it is exempt from any terse/compressed output mode. The whole point
  is fidelity to the user's natural voice.
- If asked to write something the profile doesn't cover (new channel/audience), extrapolate from the
  nearest register and note that you did.
