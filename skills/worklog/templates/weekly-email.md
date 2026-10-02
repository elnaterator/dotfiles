# Weekly summary email template

Structure for the end-of-week status email to a **manager or director**. Fill it from synthesized
worklog entries (and week-file notes as background only), then hand the result to **write-like-me**
so the final wording lands in the user's voice.

**How to use it**
- Audience is always manager/director — translate out of engineer-log language. See SKILL.md.
- Sections are a checklist, not a form. Drop any section with no real content — an empty "Blockers"
  heading reads worse than no heading.
- **1–2 tight bullets per project**, **2–4 projects**. Related daily bullets collapse into one
  impact line. This is a summary, not a replay of the week.
- Every bullet: what landed + who it helps or what changed operationally. Add "where we are" only
  when that isn't obvious.
- Never invent content to fill a section. Thin week → short email.
- Placeholders are `{{like this}}`.

---

**Subject:** Weekly update — {{Name}} — week of {{Mon DD}}

Hi {{recipient}},

{{One or two sentences framing the week: the headline outcome. Lead with the thing that mattered
most. Skip if the bullets speak for themselves.}}

**{{Project A — product/team name the reader already knows}}**
- {{Impact statement: outcome in their vocabulary. No PRs, error codes, or pipeline internals.}}
- {{Optional second bullet only if it's a different kind of outcome for the same project.}}

**{{Project B}}**
- {{...}}

**In flight**
- {{Only if something mid-flight isn't obvious from the highlights — where it stands and when it
  lands. Omit if the bullets already said it.}}

**Blockers / needs**
- {{What's stuck and the specific help or decision needed, with the owner. Omit if nothing is
  blocked — don't manufacture an ask.}}

**Next week**
- {{1–3 intended outcomes, not a task list. Omit if it's just "continue the above".}}

{{Sign-off}}
{{Name}}

---

## Shape (default — always this audience)

Manager/director weekly status. Tight bullets under project headings. Greeting and sign-off stay
unless the user asks for a 1:1 paste (then drop greeting/sign-off, keep the same bullets).

**Quarterly / multi-week roll-up** — still this audience; each bullet covers a body of work across
weeks, not a single day's accomplishment.

## Example (do imitate this density)

After a week whose log had six technical bullets (handoff internals, header names, CLI scanners,
CI stage names):

**CW2SNOW**
- Finished the support handoff. Overnight alerts now go to FSD Cloud Engineering's rota, not to me.
- Got security scanning in CI onto a path that can actually authenticate, so we aren't shipping with a scanner that never ran.

**MWatch API Gateway**
- Identifier headers (company, transaction, correlation) are in production, so those IDs show up on live traffic, not only in lower environments.

**Team templates / Harness**
- Project scaffolding now matches how we work here (Bitbucket + Jenkins), and CI is one shared stage instead of a copy per artifact type.
