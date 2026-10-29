# PRODUCT.md

What we are building and the decisions behind it. The requirements live in
[`docs/CHALLENGE.md`](docs/CHALLENGE.md); this file records how we read that
spec and what we decided where it is silent. Visual design is in
[`DESIGN.md`](DESIGN.md); engineering rules are in [`AGENTS.md`](AGENTS.md).

## What we are building

A Phoenix LiveView app that calculates the fuel needed for a mission. The user
enters the spacecraft's equipment mass and builds a flight path of `launch` /
`land` steps on Earth, Moon and Mars. The total fuel updates as they type, and
the app shows where the number comes from: fuel per step, the mass each burn
has to move, and the "fuel needs fuel" chain.

## How we read the spec

These follow from the spec's examples and are verified by script against all
four numbers it gives (13447 kg for one landing; 51898, 33388 and 212161 kg
for the three missions).

- **Each step carries the fuel for every step after it.** The mission totals
  only add up when fuel is computed from the last step back to the first: the
  launch from Earth also lifts the fuel needed to land on the Moon, take off
  again and land on Earth. Summing each step for the dry mass gives 36778 kg
  for Apollo 11 instead of 51898 kg.
- **A zero or negative result means no fuel.** The spec stops the recursion
  when additional fuel is 0 or negative. We apply the same rule to the first
  calculation of a step, so a light ship can need no fuel for a step (e.g.
  100 kg landing on the Moon).
- **The three example missions are acceptance tests**, and they double as
  one-click presets in the UI, so the demo and the tests cannot drift apart.

## Calculation

- **Exact integer arithmetic.** Gravity is stored in thousandths (Earth 9807,
  Moon 1620, Mars 3711) and the formula uses integer floor division. Floats are
  not good enough: the equipment mass is capped at 10⁹ kg, but the mass a burn
  carries (ship plus all later fuel) can reach about 2.4×10¹³ kg (the wet
  mass about 4.1×10¹³ kg), and there floats round wrongly. For 797,164,543 kg and 20 launches from Earth, floats
  give 1 kg too much. Integers are exact by construction; a test pins that
  case.
- **Every planet must keep the fuel chain short.** Each link of the chain must
  be at most half the mass it lifts (gravity × 0.042 ≤ 0.5; Earth is 0.41), so
  even the heaviest mission needs fewer than about 45 links per step. At 1 or
  more the chain would never end. A planet that breaks the rule fails the
  build, so adding a planet stays a one-line change.
- **Calculations on validated input cannot fail**, so they return their
  result directly instead of a success tuple; there is no error path for
  callers to handle that can never happen.

## Input and validation

- **Mass is whole kilograms, from 1 to 1,000,000,000 kg.** All spec examples
  are whole kilograms, so we keep the input simple and exact. Digits may be
  grouped in threes with commas, and the field groups them as you type
  ("28801" becomes "28,801"), because large masses are hard to read without
  separators. A value that can't be read is left exactly as typed, next to
  the message. Surrounding spaces are ignored; signs, decimals,
  exponents ("1e5"), badly grouped separators ("28,80,1") and units are
  rejected with a message that says what to type, e.g. "Use whole kilograms,
  for example 28801 or 28,801." The upper limit covers any real spacecraft (a
  Saturn V is about 2.9 million kg) and bounds untrusted input.
- **The mass field is plain text with a numeric keypad**, not a number input.
  Browsers send an empty value for half-typed numbers in number inputs, which
  would hide what the user typed from validation.
- **A flight path holds at most 20 steps.** That is three times the longest
  spec mission, bounds the work per keystroke, and protects against oversized
  requests. The limit is checked before anything else is processed.
- **An empty flight path is valid**, not an error. Nobody has done anything
  wrong yet, so the UI shows an empty state with the presets instead of a red
  message.
- **Planet and action values only come from a fixed list.** Anything else
  (e.g. a tampered request with "pluto") is rejected and never turned into an
  atom.

## Flight path editing

- **Steps can be added, removed and moved up or down.** The spec asks for add
  and remove. Moving with up/down buttons is cheap, works with a keyboard and
  screen readers, and needs no drag-and-drop library.
- **"Add step" suggests the next logical step.** After "Land on Moon" the
  button reads "Add step · Launch from Moon"; after a launch it suggests a
  landing. Building Apollo 11 from scratch takes four clicks and one planet
  change. The suggestion can be changed after adding.
- **The path is checked for physical sense, but never blocked.** Launching
  from a planet the ship isn't on, launching while in flight, or landing
  while landed shows a warning with two one-tap fixes:
  - **add the missing steps before this one** (e.g. "Add Launch from Moon
    before"), which keeps what the user entered and repairs a path with a
    step left out in one tap;
  - **change this step** (e.g. "Change to Launch from Moon").

  The total is still calculated: the formula doesn't depend on continuity,
  and users may want to model a single leg.
- **Removing a step, clearing the path or loading a preset over edits can be
  undone** for ten seconds, or longer while the toast is pointed at or
  focused, so these actions need no confirmation dialog.

## Results

- **The total is the largest thing on the screen**, with the wet mass
  (ship plus all fuel), the mass ratio, the route and the step count next to it.
- **Each step shows its fuel and its mass at burn** (ship plus fuel for all
  later steps), and the selected step shows its fuel chain. This explains
  the backward pass without a lecture, and every number on screen is one the
  calculation already produces.
- **Invalid input never shows a number.** While the mass is invalid the total
  shows "—" with the reason, so nobody copies a stale value.
- **A step that needs no fuel shows the arithmetic**, exact and unrounded,
  e.g. "100 × 1.62 × 0.033 − 42 = −36.654", so a 0 doesn't look like a bug.
- **Numbers use a thousands separator**: `51,898 kg`.

## First visit

- **The app opens with Apollo 11 loaded, clearly labelled as an example.** The
  first screen shows what the tool does and that it matches the spec, without
  any typing. "Clear path" starts a mission from scratch.
- **The three spec missions are one-click presets.** The active preset is
  highlighted and marked "modified" while the mission differs from it;
  editing it back (however the mass is written) clears the mark.

## Live updates

- **Every edit recalculates immediately.** Typing in the mass field waits
  250 ms after the last keystroke, so typing "28801" doesn't flash five
  intermediate totals; buttons and choices update instantly.
- **A dropped connection doesn't lose work.** LiveView restores the form after
  reconnecting, and the screen says values may be out of date while offline.
  A page refresh starts again from the example; shareable mission links are
  out of scope for now.

## Look and feel

Decided in detail in [`DESIGN.md`](DESIGN.md). In short:

- **Flight spine layout:** a vertical mission profile beside the editable
  steps. Each launch arc rises and each landing arc descends, and the line
  gets thinner after every burn, showing that earlier steps carry later fuel.
- **Highlighter style:** numbers stay ink-coloured; one violet marker means fuel
  and appears as a band under the total, bars, burn rings and the selected
  arc.
- **Light and dark themes that mirror each other**, so switching feels like
  dimming the same product. Every colour pair meets WCAG AA.
- **Errors and warnings look and behave differently.** Errors are red with an
  x-circle and block the total; warnings are amber with a triangle,
  keep the total and offer a fix.
- **Motion only explains change** (the total rolling to its new value, rows
  sliding in, arcs drawing on) and switches off for users who turn motion
  off.

## Technology

- **Current stable Phoenix 1.8 and LiveView**, not the 1.8.0-rc the spec
  mentions. The spec only says we can use the rc; stable has the same DaisyUI
  integration plus security fixes.
- **No database.** The app keeps no data between visits.
- **Forms use Ecto embedded schemas** (`ecto` and `phoenix_ecto`, no
  `ecto_sql`). This is how Phoenix forms show per-field errors and validate
  nested rows; the calculation core never sees Ecto. Adding, moving and
  removing steps are explicit server events, because they need prefilled steps
  and reordering that the form's built-in add/remove can't express.
- **Generated without mailer and dashboard.** Neither is needed.
- **Dependencies follow a 7-day release cooldown, with a 3-day exception when
  the newer release fixes something that matters to us:** Bandit 1.14.0
  (12 security advisories, several on our HTTP and WebSocket path),
  plug_crypto 2.2.1 (a CVE that can leak `secret_key_base` into logs), and
  tailwind 0.5.2 and elixir_make 0.10.1 (both needed to download their tools
  on OTP 29). Bandit moves to 1.14.1 once it is eligible; it only fixes an
  HTTP/2 issue we don't use. Each exception is commented next to the
  dependency.
- **Quality tools:** Credo, Dialyzer, StreamData for property tests, and
  mix_audit and Sobelow for security checks. Coverage uses the built-in
  `mix test --cover`.

## Out of scope

- Accounts, saved missions and shareable mission links.
- Drag-and-drop reordering, browser end-to-end tests, localisation.

When time runs short, extras (presets, reordering, mission profile, motion)
are cut first; the spec's requirements never are.
