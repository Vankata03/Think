# Think content audit

Audit date: 2026-07-10

This is an editorial and provenance review, not legal advice. Counsel should
review the final release catalog for every country where the app is sold.

## Outcome

The previous catalog had 118 lines and 90 questions. They advanced on separate
modulo rotations, so a line did not keep a stable relationship with its
question. The replacement catalog contains 100 complete practices:

- 82 original Think lines.
- 18 attributed lines from two identified George Long translations.
- One question written for the meaning of each line.
- One concrete action written for the same line, generally completable in ten
  minutes or less.
- Machine-checked uniqueness, non-empty content, length limits, pairing, and
  source presence for attributed text.

The Today screen now exposes the action as **Today's move**. Widgets, Watch,
share cards, Focus, and notifications continue to consume the same `Quote`
model. House lines are not presented as quotations by a named third party.

## Why the old catalog did not pass

The old comments described the material as public domain, but the data did not
record a work, passage, translator, edition, or source URL. That made the claim
impossible to verify during release review.

The highest-risk groups were removed rather than rationalized:

- Modern-sounding translations of ancient authors with no edition. An ancient
  underlying work can be public domain while a modern translation remains a
  protected derivative work.
- Familiar sayings assigned to Marcus Aurelius, Seneca, Epictetus, Socrates,
  Confucius, Lao Tzu, or the Buddha without a primary-text locator.
- Internet “Chinese proverb,” “Japanese proverb,” “Zen proverb,” and generic
  “Proverb” labels with no traceable edition or collector.
- House lines that were established motivational slogans or only lightly
  varied versions of them.
- Generic encouragement that did not create a decision, reveal a tradeoff, or
  lead to an action.

Examples removed under the source-or-delete rule include “What we do now
echoes in eternity,” “Luck is what happens when preparation meets
opportunity,” “Do it scared,” and “The best time to plant a tree...” The audit
does not need to prove a competing attribution: absence of a reviewable source
is enough to keep a line out of a commercial catalog.

## Release rule for attributed lines

An attributed line ships only when its record contains all of these:

1. Exact displayed text checked against the named edition.
2. Author, work, and passage locator.
3. Translator or editor identity where applicable.
4. Evidence that both the underlying work and displayed translation are out of
   copyright in target territories, or a written license covering the use.
5. A stable source URL retained in the content record.

The current attributed set uses only:

- Marcus Aurelius, *Thoughts of Marcus Aurelius*, George Long translation,
  Project Gutenberg eBook 6920.
- Epictetus, *A Selection from the Discourses of Epictetus with the
  Encheiridion*, George Long translation, Project Gutenberg eBook 10661.

George Long died in 1879. Project Gutenberg marks both editions public domain
in the United States. The old translator also clears the European Union's
general life-plus-70 term. This is substantially safer than copying a polished
modern rendering, but storefront expansion still requires a jurisdictional
check.

## Legal basis used for the policy

- U.S. law expressly names translations as derivative works. Public-domain
  status of Marcus Aurelius or Epictetus therefore does not automatically clear
  a recent English rendering: [17 U.S.C. §§101 and 103](https://www.copyright.gov/title17/92chap1.html).
- The U.S. Copyright Office says all works published in the United States
  before January 1, 1931 are currently public domain, while warning that term
  analysis depends on publication facts: [What Is Copyright?](https://www.copyright.gov/what-is-copyright/)
  and [Circular 15A](https://www.copyright.gov/circs/circ15a.pdf).
- The EU's general term is the author's life plus 70 years: [Directive
  2006/116/EC, Article 1](https://eur-lex.europa.eu/legal-content/EN/TXT/PDF/?uri=CELEX:02006L0116-20111031).
- Names, titles, slogans, and short phrases generally lack U.S. copyright
  protection, but that is not a blanket clearance for longer quotation text or
  trademark use: [Copyright Office Circular 33](https://www.copyright.gov/circs/circ33.pdf).
- Fair use is fact-specific and commercial purpose is one of the factors. Think
  should not use fair use as the ordinary content-acquisition strategy:
  [Copyright Office fair-use guidance](https://www.copyright.gov/fair-use/more-info.html).
- Source editions: [Marcus Aurelius eBook
  6920](https://www.gutenberg.org/ebooks/6920) and [Epictetus eBook
  10661](https://www.gutenberg.org/ebooks/10661).

## Editorial standard

Every practice should do three different jobs:

- **Line:** expose a tension, hidden cost, contradiction, or choice. Avoid
  praise, hype, destiny language, and empty “keep going” encouragement.
- **Question:** demand evidence from the user's real behavior. Avoid merely
  restating the line and avoid shame as a motivational device.
- **Action:** be observable, small, and possible today. Prefer changing an
  object, sentence, calendar block, boundary, or first step over asking the user
  to “be mindful” or “believe.”

Content should also remain usable on compact widgets and Watch layouts. A line
may contain at most 100 characters and 20 words; questions and actions retain a
150-character safety ceiling. This is an editorial limit enforced by tests, not
automatic UI truncation or font shrinking.

## Remaining release checks

- Have a human editor read all 100 practices aloud and flag repeated metaphors,
  accidental harshness, and lines that sound clever before they sound true.
- Run exact-phrase web and trademark searches for the 82 house lines. OpenAI's
  [terms](https://openai.com/policies/terms-of-use/) assign output rights to the
  user as between the user and OpenAI, but also warn that output may not be
  unique; ownership language is not third-party clearance.
- Keep a frozen content manifest for every release so a challenged line can be
  identified and removed without waiting for an app binary update.
- Recheck source rules before localization. A new translation is new expression;
  do not translate an English public-domain quote casually and continue to call
  it a verbatim quotation. Use a cleared translation in the target language or
  label a faithful house rendering as an adaptation.
