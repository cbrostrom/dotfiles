---
name: unslop
description: "Cut AI tells from writing. Add human voice. 31 patterns. Triggers: unslop, humanize, write, draft, polish, edit, rewrite."
---

# Unslop

Scan → rewrite preserving meaning → add soul → self-audit: "What makes this obviously AI?" Fix remaining tells.

## Adding soul

Removing patterns is half the job. Sterile, voiceless writing is just as obvious.

- **Have opinions.** React to facts instead of neutrally listing pros and cons.
- **Vary rhythm.** Short sentences. Then longer ones that take their time. Mix it up.
- **Acknowledge complexity.** "Impressive but also kind of unsettling" beats "impressive."
- **Use "I" when it fits.** First person isn't unprofessional.
- **Let some mess in.** Perfect structure looks machine-made.
- **Be specific.** Not "this is concerning" but "there's something unsettling about agents churning away at 3am."

## Content

1. **Puffery.** "pivotal moment", "testament to", "evolving landscape", "setting the stage for", "indelible mark", "deeply rooted". Cut — state what happened.
2. **Name-dropping.** Listing outlets without context. Pick one, say what was said.
3. **Superficial -ing phrases.** "highlighting...", "ensuring...", "reflecting...", "showcasing...", "fostering...". Delete or expand with real sources.
4. **Promotional language.** "nestled", "vibrant", "breathtaking", "groundbreaking", "renowned", "stunning", "must-visit". Use neutral descriptions.
5. **Vague attributions.** "Experts believe", "Industry reports suggest", "Some critics argue". Name the source or delete.
6. **Formulaic challenges.** "Despite challenges... continues to thrive." Replace with specific facts.

## Language

7. **AI vocabulary.** Additionally, crucial, delve, enduring, enhance, fostering, garner, interplay, intricate, landscape (abstract), pivotal, showcase, tapestry (abstract), testament, underscore, vibrant. Replace with plain words.
8. **Fancy "is".** "serves as", "stands as", "boasts", "features". Say "is" or "has".
9. **"Not just X, but Y."** State the point directly.
10. **Rule of three.** Don't force ideas into groups of three. Use the natural number.
11. **Synonym cycling.** Pick one word for a thing and repeat it. Don't rotate synonyms.
12. **False ranges.** "from X to Y" where X and Y aren't on a meaningful scale. List topics directly.

## Style

13. **Em dashes.** Avoid entirely — no en dashes or hyphen-as-dash substitutes either. End the sentence or use a comma.
14. **Colon overuse.** Only before a list or example, not mid-sentence. "If you're coming from traditional automation: instead of registering event handlers..." → "Describing when the scheduler should fire works best as plain English."
15. **Boldface overuse.** Don't bold every proper noun or acronym.
16. **Inline-header lists.** "**Performance:** Performance improved..." is a tell. Convert to prose. A bold lead-in ending in a period with genuinely new detail is fine: "**Schema in TypeScript.** Tables live in one file."
17. **Title case headings.** Use sentence case.
18. **Decorative emojis.** Remove from headings and bullets.
19. **Curly quotes.** Replace with straight quotes.

## Communication artifacts

20. **Chatbot phrases.** "I hope this helps!", "Let me know if...", "Of course!", "Certainly!", "Found the smoking gun!" Remove.
21. **Cutoff disclaimers.** "While specific details are limited..." Find sources or remove.
22. **Sycophantic tone.** "Great question! You're absolutely right!" Respond directly.

## Filler

23. **Filler phrases.** "In order to"→"To". "Due to the fact that"→"Because". "It is important to note that"→delete.
24. **Excessive hedging.** "could potentially possibly be argued that it might"→"may".
25. **Generic conclusions.** "The future looks bright." State specific plans or facts.

## Jargon

26. **Abstract metaphor nouns.** Replace with the concrete word: substrate→base, wedge in→add, vector→way/method, locus/nexus→[the actual thing], surface (API surface)→[scope/interface], bedrock/scaffolding→foundation/structure, modality→mode, paradigm→approach, gold-plating→more than needed, ratchet→[mechanism name] or "limit that only tightens", evacuate→move out, endgame→last phase, north star→goal, flywheel→[the actual mechanism].

## Plain speech

27. **Name the mechanism, not the feeling.** "the database stays close at hand" names a feeling; "`.toSQL()` returns the exact string" names a mechanism. If you can't restate as a concrete instruction, fact, or number, cut it. If the sentence could appear unchanged in another project's docs, it says nothing about this one — cut it.
28. **Split dense sentences.** If the reader has to backtrack, break it in two or drop clauses. One idea per sentence.
29. **Active voice.** "queries are validated"→"the compiler validates queries". Passive is fine only when the actor is unknown or irrelevant.
30. **Cut adverbs, use a stronger verb.** "runs quickly"→"is fast" or a number. An adverb propping up a weak verb means the verb is wrong.
31. **Prefer the plain word.** utilize→use, leverage→use, facilitate→help, numerous→many, "in the event that"→if.
