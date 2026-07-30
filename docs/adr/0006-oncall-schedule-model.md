# 0006. Model on-call as layered rotations resolved by a pure function

- **Status:** Proposed
- **Date:** 2026-07-30
- **Deciders:** @darisadam

## Context

Scheduling is where on-call tools accumulate their worst bugs, and the bugs are
all time bugs: DST transitions that skip or double a shift, handoffs computed
in the wrong timezone, overrides that half-apply. The classic incident is "the
schedule looked right in the UI but paged the wrong person" — the UI and the
paging path computed on-call *differently*.

Requirements from the PRD: daily/weekly/custom rotations, multi-timezone
teams, handoff at a configurable local time, override layers, an ICS feed, and
"who is on call *right now*" as an input to escalation.

## Decision

1. **Data model**: a `schedule` has an IANA timezone and ordered `layers`;
   each layer has an ordered participant list, a rotation length, an anchor
   ("virtual start") instant, and optional time-of-day/day-of-week
   *restrictions* (for follow-the-sun). `overrides` are absolute
   `[start, end)` intervals at schedule level naming one user.
2. **Resolution is one pure function**:
   `resolve(scheduleDefinition, instant) → user | none`, with precedence:
   override wins; otherwise the highest-numbered layer whose rotation and
   restrictions cover the instant; otherwise nobody. Rendering a calendar is
   `resolve` sampled over a range — the UI, the ICS feed, the chat command and
   the escalation engine all call the same function, so they cannot disagree.
3. **Storage is UTC instants plus the IANA zone name.** All rotation and
   handoff arithmetic is done in the schedule's zone via the tzdata already
   shipped in the image (never fixed offsets). Local handoff times are
   interpreted per occurrence, so a 09:00 handoff stays 09:00 local across DST.
   DST rules: a local time that does not exist (spring forward) resolves
   forward to the first valid instant; an ambiguous local time (fall back) uses
   the first occurrence. These two rules are stated in user docs and pinned by
   tests.
4. **The domain code takes an injected clock.** `time.Now()` is banned in
   schedule and escalation packages (enforced by lint), which is what makes the
   DST/property test suites possible.
5. **No materialised shift table in v1.** Resolution is computed on demand;
   it is arithmetic, not search, and O(layers) per instant. A cache can be
   added behind the same function if profiling ever demands it.
6. **Empty resolution is loud.** If a policy step targets a schedule that
   resolves to nobody, the step is skipped with a timeline warning and an
   admin-visible system notice — never a silent no-page.

## Consequences

### Positive

- One implementation of the hardest logic in the product, exhaustively
  testable in isolation (property tests: exactly-one-on-call whenever a layer
  is non-empty and unrestricted; continuity across handoffs; override
  boundaries are exact).
- A fixed DST regression matrix (spring/fall in America/New_York and
  Europe/London, plus non-hour offsets: Asia/Kolkata +05:30,
  Australia/Lord_Howe +10:30/+11:00, Pacific/Chatham +12:45) runs in CI
  forever.

### Negative

- On-demand resolution recomputes per query; large calendar renders do
  O(samples × layers) work. Acceptable at human-schedule scale; the pure
  function leaves room for a cache.
- Restrictions make the coverage logic genuinely harder; they are scoped as
  Should for v1 and may slip to v1.1 without breaking the model.

### Neutral

- The schema in migration 001 (layers, participants, overrides) is close;
  v2 adds rotation length, anchor instant, and restrictions rather than
  reshaping it.

## Alternatives considered

**Materialised shifts (generate rows for the next N months).** What several
incumbents do. Rejected for v1: every edit becomes a regeneration with
consistency questions (what if paging reads mid-regeneration?), and drift
between generator and reader reintroduces the "UI said X, pager did Y" bug
class.

**RRULE (RFC 5545 recurrence) as the source of truth.** Tempting since we
export ICS anyway. Rejected: RRULE cannot express layered precedence or
restrictions cleanly, and debugging RRULE edge cases is its own career. ICS
stays an *export* format.

**Fixed UTC offsets per schedule.** Simpler, wrong: breaks every DST
transition, which is the main thing to get right.
