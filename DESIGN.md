# DESIGN.md

Visual and interaction design for the Fuel Calculator UI. It applies to the
app and to any generated docs or HTML pages in `docs/`. Product decisions
(what the UI does) live in [`PRODUCT.md`](PRODUCT.md); this file covers how it
looks, moves and reads.

## Principles

1. **Colour means data.** The UI chrome is neutral warm stone. One colour, violet,
   means fuel and nothing else. Planets have their own dot colours. Status
   colour appears only when something needs attention: amber for path
   warnings, red for errors.
2. **Numbers stay ink.** Fuel figures are never coloured text. The fuel colour
   appears as marks around them: the highlighter band under the total, bars,
   burn rings, the selected arc.
3. **One product, dimmed.** The light theme mirrors the dark one. Nothing is
   pure white or pure black; the page is warm stone and content sits on soft
   cards.
4. **Motion explains change.** Animations show what changed and where, last
   120–450 ms, and never loop.
5. **Errors and warnings differ by more than colour.** Icon, outline style and
   behaviour all differ.

## Themes

Two DaisyUI 5 themes named `light` (default) and `dark` (used when the system
prefers dark), so Phoenix's theme toggle works unchanged. The direction is
**stone & violet**: a warm stone page, soft rounded cards and pill controls,
with violet marking fuel. The light theme mirrors the dark one.

### Tokens

| Token | Light | Dark | Used for |
|---|---|---|---|
| Page | `#F1EFEC` | `#19171D` | page background (`base-200`), input and segment tracks |
| Surface | `#FBFAF8` | `#221F27` | cards, pinned bar (`base-100`) |
| Surface 2 | `#E6E2DD` | `#2D2933` | bar tracks (`base-300`) |
| Rule | `#E4E0DA` | `#2E2A34` | card borders, row dividers |
| Rule strong | `#B3ACA4` | `#4D4756` | spine rails |
| Control | `#857E78` | `#776F80` | focus outlines and quiet borders (`neutral`) |
| Ink | `#1F1B24` | `#EEEAF2` | text and all numbers, including fuel |
| Muted | `#5A5560` | `#ABA4B4` | labels, units, secondary text |
| Fuel fill | `#7354E8` | `#A893FF` | step bars, burn halos, chain bars (`accent`) |
| Fuel arc (selected) | `#5F42D6` | `#A893FF` | arc of the selected step |
| Fuel mark | `#D9CFFF` | `#3E3172` | band behind the total |
| Selected step number | `#D9CFFF` | `#A893FF` | disc of the selected step, with `accent-content` ink |
| Spine | `#88817B` | `#857D8E` | arcs of unselected steps |
| Warning text / background / border / icon | `#7A4600` / `#FDF0D5` / `#B7791F` / `#9A5B00` | `#F6C76E` / `#33291A` / `#C58F2E` / `#F2B544` | path warnings |
| Error | `#B42318` | `#FF8A8A` | error text, x-circle, invalid input border |
| Earth / Moon / Mars | `#2C6DB5` / `#7B7570` / `#B5622B` | `#6CA8EE` / `#C4BECB` / `#E08E5A` | planet rings and dots |

Shadows are tokens too: `--panel-shadow` (soft, for cards) and
`--float-shadow` (stronger, for the pinned bar and the undo toast).

### Contrast (WCAG 2.x, measured)

| Pair | Light | Dark | Needed |
|---|---|---|---|
| Ink on page | 14.8 | 15.0 | 4.5 |
| Total (ink) on fuel mark | 11.5 | 9.4 | 7 (our target) |
| Muted on page / card | 6.3 / 6.9 | 7.4 / 6.7 | 4.5 |
| Error on page | 5.7 | 7.8 | 4.5 |
| Control on page | 3.5 | 3.7 | 3 |
| Fuel fill on page | 4.4 | 7.0 | 3 |
| Inactive arc on page | 3.3 | 4.5 | 3 |
| Planets on page | 3.9–4.6 | 6.9–9.8 | 3 |
| Warning text on its background | 6.9 | 9.0 | 4.5 |

Any new colour pair must be measured and meet these targets before it ships.

### DaisyUI 5 mapping

The theme blocks live in `assets/css/app.css`. Primary is the ink colour (dark
buttons on light, light buttons on dark), `accent` is the fuel violet,
`warning` amber and `error` red. Radii: `--radius-box` 1.25rem (cards),
`--radius-field` 0.75rem (inputs, warning boxes), `--radius-selector` 2rem;
segmented controls, presets, Add step and the toast are fully rounded pills.
`--border` 1px, `--depth` 0 (cards get their depth from `--panel-shadow`),
`--noise` 0.

- `accent` is the fuel colour. Never use it for anything that isn't fuel.
- `success` shares the violet. Use it only for confirmations, and always with
  an icon and text, so violet keeps meaning fuel.
- `warning` is amber. Path warnings must be noticed without blocking
  anything, so they get a tinted box, a solid triangle and a link from the
  summary.

## Typography

| Role | Face | Notes |
|---|---|---|
| Text | Instrument Sans (variable, `wdth` 75–100) | body 15px; section labels 12–13px, `wdth` 85, weight 600, uppercase, `0.08em` tracking |
| Numbers, units, wordmark | Martian Mono (variable, `wdth` 75–112.5) | always `font-variant-numeric: tabular-nums slashed-zero` |

- Hero total: `clamp(36px, 12cqi, 58px)`, weight 700. When it exceeds 11
  characters (e.g. `2,847,201,148`) switch to `wdth` 87 so it never overflows
  its panel.
- Numbers use a thousands separator: `51,898 kg`.
- Load both faces from Google Fonts with system fallbacks.

## Layout: the flight spine

Desktop, one column of content, max width about 1240px.

1. **Header:** `FUEL/CALC` wordmark with the launch glyph; theme toggle on the
   right.
2. **Spacecraft + summary row:**
   - Left: equipment mass input with a `kg` unit and the "Start from" preset
     buttons.
   - Right: the summary panel. Total fuel on the highlighter band, then wet
     mass, mass ratio, route, and steps out of 20. A path-warning badge
     appears here when the path has warnings.
3. **Flight path:** one row per step, in flight order.
   - Left gutter: the step number (a button that selects the step).
   - Spine column (200px): the step's arc. A launch rises from the surface rail
     to the orbit rail, a landing descends. Stroke width is proportional to the
     mass at burn, so the line visibly thins after each burn. A burn ring at the
     surface end is sized by the step's fuel.
   - Row content: Launch/Land segmented control, body segmented control
     (Earth / Moon / Mars with planet dots), step fuel with a bar, move up /
     move down / remove, and "Mass at burn … · ship + fuel for steps …".
   - The selected row expands to show its fuel chain as bars that shrink step
     by step, then the step total.
   - After the last row: a dashed "ghost" arc and the Add step button labelled
     with the suggested next step.
4. **How fuel is calculated:** a collapsed disclosure with the formulas and
   gravities.
5. **Pinned total bar:** a floating rounded bar at the bottom of the viewport, shown once the summary
   scrolls away.

On phones the spine is hidden (it needs about 200px of width) and each step
keeps its number and fuel bar. The total and Add step live in a bottom bar,
and move/remove go into a ⋮ menu.

Shapes: three soft cards (spacecraft, summary, flight path) on the stone
page, 20px corners, soft shadows. Inputs sit on a stone track and turn white
with a violet border when focused. Choices are pill-shaped segmented
controls where the selected option is a raised white chip. Inside cards,
rows are separated by hairlines; the selected row gets a light stone tint.
Burn markers ("filled ring") look the same in both themes: a violet-tinted
disc with a solid violet edge (18–32px, sized by fuel; 35% fill, 70% when the
step is selected), separated from the arc by a gap in the card colour, around
a planet-coloured dot with a card-coloured border.

## States

| State | Treatment |
|---|---|
| Validation error | Red border on the field, x-circle + message below it (`aria-describedby`). The total shows `—` with the reason. Shown after the debounce or on blur, never on the first keystroke |
| Path warning | Amber box with a solid triangle, "Check path." + explanation, and two fix buttons: add the missing steps before this one (primary, e.g. "Add Launch from Moon before") and change this step (secondary, e.g. "Change to Launch from Moon"). The step number and the spine's jump line turn amber, and the summary and pinned bar show a badge linking to the first warning. The total stays |
| Zero-fuel step | `0 kg` with the exact arithmetic under the step and in its fuel chain, e.g. `100 × 1.62 × 0.033 − 42 = −36.654` |
| Empty path | "No steps yet" with the three presets; total `—` |
| Step limit | Add step looks disabled but stays focusable (`aria-disabled`), described by "A flight path holds up to 20 steps." in neutral styling. The same goes for a warning's "Add … before" fix when the steps wouldn't fit |
| Invalid step or too many steps | x-circle + message on the step ("Choose Earth, Moon or Mars.") or under the path ("A flight path holds up to 20 steps.") |
| Reconnecting | Notice "Reconnecting. Values may be out of date." and the summary, steps and pinned bar dimmed, driven by LiveView's `.phx-client-error` / `.phx-server-error` classes |
| Undo | Toast after remove, clear or loading a preset over edits, with an Undo button. 10 s, paused while pointed at or focused. Focus moves to Undo after remove or clear, to the restored step after undo, and back to the path if the toast closes while focused |

## Motion

| Animation | Trigger | Spec |
|---|---|---|
| Total rolls to the new value | total changes | 450 ms ease-out; a small colocated hook; retargets if interrupted; a separate hidden live region announces the final value |
| Total ↔ `—` | validation error appears or clears | 180 ms fade in |
| Row enters | add step, a preset with more steps | 320 ms slide and fade, then a brief highlight fades out. Loading a preset reuses the rows on screen (ids by position), so they update in place instead of re-entering; preset rows get ids from the preset and position, so the first load and the connected page render the same rows and nothing animates twice |
| Row exits | remove | Removed instantly; the undo toast confirms. An exit fade kept the row in the list for a moment and made the list jump |
| Arc enters | new step | 420 ms fade in; burn ring pops after 300 ms. (A `stroke-dashoffset` draw-on doesn't combine reliably with the non-scaling strokes the stretched spine needs) |
| Fuel bars | any recalculation | `transform: scaleX` transition, 320 ms (never animate `width`) |
| Chain bars | select a step | grow left to right, 40 ms stagger |
| Validation message | error shown | 180 ms fade in; no shake |

Easing: `cubic-bezier(.2,.8,.2,1)` for entering, `cubic-bezier(.6,0,.2,1)` for
drawing. Step rows need stable DOM ids (from step ids, never the index) so
enter and exit animations hit the right row. Under
`prefers-reduced-motion: reduce`, every animation and transition is
effectively instant.

Not used: starfields, rockets flying along the path, confetti, looping glows,
shake on error.

## Accessibility

- Launch/Land and the planet choice are real radio groups (segmented look);
  the chosen option has a neutral ring as well as the raised chip.
- The step number is a real button that expands the step's fuel chain
  (`aria-expanded`, `aria-controls`), named "Step 02, fuel chain".
- One polite live region announces the settled total with the number of path
  warnings, or why there is no total. Warning boxes are not live regions.
- Step fuel is labelled for screen readers ("Fuel for step 2:"), and the
  mass input describes its unit and range.
- Unavailable actions use `aria-disabled`, so they stay focusable and their
  reason is read. The pinned bar is `inert` while slid away on wider screens.
- After an edit removes or moves the focused control, focus moves to the
  next sensible place (the moved step's button, its phone menu, the fixed
  step, Undo).
- Icon-only buttons have `aria-label`s. The spine SVG is decorative
  (`aria-hidden`); the rows are the accessible source of truth.
- Visible focus on every control: a 2px ink outline.
- Touch targets are at least 44px on touch screens (`pointer: coarse`).
- Colours that must be told apart also differ in lightness, not hue alone.

## Iconography

- Heroicons outline (shipped with Phoenix 1.8) for chrome: arrows, x-mark,
  exclamation-triangle (warning), x-circle (error), arrow-uturn-left (undo),
  sun / moon (theme).
- Custom 16px glyphs: launch (arc leaving a ground line) and land (arc meeting
  it); planet dots with a small mark (Earth meridian, Moon craters, Mars polar
  cap).
- No emoji, no mixing Unicode arrows with SVG icons.
