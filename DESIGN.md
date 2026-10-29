# DESIGN.md

Visual and interaction design for the Fuel Calculator UI. It applies to the
app and to any generated docs or HTML pages in `docs/`. Product decisions
(what the UI does) live in [`PRODUCT.md`](PRODUCT.md); this file covers how it
looks, moves and reads.

## Principles

1. **Colour means data.** The UI chrome is neutral slate. One colour, mint,
   means fuel and nothing else. Planets have their own dot colours. Status
   colour appears only when something is wrong.
2. **Numbers stay ink.** Fuel figures are never coloured text. The fuel colour
   appears as marks around them: the highlighter band under the total, bars,
   burn rings, the selected arc.
3. **One product, dimmed.** The light theme mirrors the dark one: the light
   page is the dark ink and the light ink is the dark page. Nothing is pure
   white or pure black.
4. **Motion explains change.** Animations show what changed and where, last
   120–450 ms, and never loop.
5. **Errors and warnings differ by more than colour.** Icon, outline style and
   behaviour all differ.

## Themes

Two DaisyUI 5 themes: `fuel-light` (default) and `fuel-dark` (used when the
system prefers dark). The Phoenix 1.8 theme toggle offers system / light /
dark.

### Tokens

| Token | Light | Dark | Used for |
|---|---|---|---|
| Page | `#E9EEF4` | `#161C24` | page background (`base-200`) |
| Surface | `#F6F8FB` | `#1E2630` | panels, inputs, summary, pinned bar (`base-100`) |
| Surface 2 | `#DCE3EB` | `#27313D` | selected segment, bar tracks (`base-300`) |
| Rule | `#D0D8E1` | `#2F3A47` | row dividers |
| Rule strong | `#A9B4C1` | `#465364` | section rules, spine rails |
| Control | `#748296` | `#6B7A8C` | input and segment borders, warning outline |
| Ink | `#161C24` | `#E9EEF4` | text and all numbers, including fuel |
| Muted | `#4A5767` | `#A1AEBE` | labels, units, secondary text |
| Fuel fill | `#18915F` | `#4FCF97` | step bars, burn rings, chain bars |
| Fuel arc (selected) | `#14805A` | `#4FCF97` | arc of the selected step |
| Fuel mark | `#96E2BF` | `#215747` | solid band behind the total and pinned total |
| Selected step number | `#96E2BF` fill, `#161C24` border | `#4FCF97` fill and border | number text `#121416` |
| Spine | `#7A8697` | `#768699` | arcs of unselected steps |
| Error | `#B42318` | `#FF8A8A` | error text, x-circle, invalid input border |
| Earth | `#2C6DB5` | `#5A9FE8` | planet dot |
| Moon | `#717C89` | `#B4BFCC` | planet dot |
| Mars | `#B5622B` | `#DE8A4E` | planet dot |

### Contrast (WCAG 2.x, measured)

| Pair | Light | Dark | Needed |
|---|---|---|---|
| Ink on page | 14.7 | 14.7 | 4.5 |
| Total (ink) on fuel mark | 11.4 | 7.2 | 7 (our target) |
| Muted on page / panel | 6.3 / 6.9 | 7.6 / 6.8 | 4.5 |
| Error on page | 5.6 | 7.6 | 4.5 |
| Control border on page | 3.4 | 3.9 | 3 |
| Fuel bars on page | 3.4 | 8.7 | 3 |
| Inactive arc on page | 3.2 | 4.6 | 3 |
| Planet dots on page | 3.6–4.5 | 6.2–9.2 | 3 |

Any new colour pair must be measured and meet these targets before it ships.

### DaisyUI 5 mapping

```css
@plugin "daisyui/theme" {
  name: "fuel-light"; default: true; color-scheme: light;
  --color-base-100: #F6F8FB;
  --color-base-200: #E9EEF4;
  --color-base-300: #DCE3EB;
  --color-base-content: #161C24;
  --color-primary: #161C24;   --color-primary-content: #F6F8FB;
  --color-accent: #18915F;    --color-accent-content: #161C24;
  --color-neutral: #748296;   --color-neutral-content: #161C24;
  --color-error: #B42318;     --color-error-content: #F6F8FB;
  --color-warning: #4A5767;   --color-warning-content: #F6F8FB;
  --color-info: #2C6DB5;      --color-info-content: #F6F8FB;
  --color-success: #14805A;   --color-success-content: #F6F8FB;
  --radius-selector: 0.375rem; --radius-field: 0.375rem; --radius-box: 0.625rem;
  --size-selector: 0.25rem; --size-field: 0.25rem;
  --border: 1px; --depth: 0; --noise: 0;
}

@plugin "daisyui/theme" {
  name: "fuel-dark"; prefersdark: true; color-scheme: dark;
  --color-base-100: #1E2630;
  --color-base-200: #161C24;
  --color-base-300: #27313D;
  --color-base-content: #E9EEF4;
  --color-primary: #E9EEF4;   --color-primary-content: #161C24;
  --color-accent: #4FCF97;    --color-accent-content: #121416;
  --color-neutral: #6B7A8C;   --color-neutral-content: #E9EEF4;
  --color-error: #FF8A8A;     --color-error-content: #161C24;
  --color-warning: #A1AEBE;   --color-warning-content: #161C24;
  --color-info: #5A9FE8;      --color-info-content: #161C24;
  --color-success: #4FCF97;   --color-success-content: #121416;
  --radius-selector: 0.375rem; --radius-field: 0.375rem; --radius-box: 0.625rem;
  --size-selector: 0.25rem; --size-field: 0.25rem;
  --border: 1px; --depth: 0; --noise: 0;
}
```

DaisyUI has no slot for these, so they are custom properties defined per theme
next to the theme blocks: `--fuel-mark`, `--fuel-arc-selected`, `--muted`,
`--rule`, `--rule-strong`, `--spine`, `--planet-earth`, `--planet-moon`,
`--planet-mars`.

- Primary buttons are ink-filled (`primary`), not coloured.
- `accent` is the fuel colour. Never use it for anything that isn't fuel.
- `success` shares the mint. Use it only for confirmations, and always with
  an icon and text, so mint keeps meaning fuel.
- `warning` is deliberately hue-less: warnings are a dashed `neutral` outline
  with a triangle, never a coloured fill.

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
5. **Pinned total bar:** sticks to the bottom of the viewport once the summary
   scrolls away.

On phones the spine collapses to a thin rail beside each row. The total and
Add step live in a bottom bar, and move/remove go into a ⋮ menu.

Shapes: 6px radius for fields and segments, 10px for panels. No shadows
except the toast. Separate rows with rules rather than nested cards.

## States

| State | Treatment |
|---|---|
| Validation error | Red border on the field, x-circle + message below it (`aria-describedby`). The total shows `—` with the reason. Shown after the debounce or on blur, never on the first keystroke |
| Path warning | Dashed neutral outline, triangle, "Check path." + explanation, and two fix buttons: add the missing steps before this one (primary, e.g. "Add Launch from Moon before") and change this step (secondary, e.g. "Change to Launch from Moon"). The total stays |
| Zero-fuel step | `0 kg` with the arithmetic shown, e.g. `100 × 1.62 × 0.033 − 42 = −36.65` |
| Empty path | "No steps yet" with the three presets; total `—` |
| Step limit | Add step disabled with "A flight path holds up to 20 steps." in neutral styling |
| Reconnecting | Notice "Reconnecting. Values may be out of date." and the summary dimmed, driven by `.phx-disconnected` |
| Undo | Toast after remove, clear or loading a preset over edits; 6 s, with an Undo button |

## Motion

| Animation | Trigger | Spec |
|---|---|---|
| Total rolls to the new value | total changes | 450 ms ease-out; a small colocated hook; retargets if interrupted; a separate hidden live region announces the final value |
| Total ↔ `—` | validation error appears or clears | 160 ms crossfade |
| Row enters | add step, preset | 320 ms slide and fade; preset rows staggered 30 ms |
| Row exits | remove | 160 ms fade (`phx-remove`), then the undo toast |
| Arc draws on | new or changed step | 420 ms `stroke-dashoffset`; burn ring pops after 300 ms |
| Fuel bars | any recalculation | `transform: scaleX` transition, 320 ms (never animate `width`) |
| Chain bars | select a step | grow left to right, 40 ms stagger |
| Validation message | error shown | height reveal, 160 ms; no shake |

Easing: `cubic-bezier(.2,.8,.2,1)` for entering, `cubic-bezier(.6,0,.2,1)` for
drawing. Step rows need stable DOM ids (from step ids, never the index) so
enter and exit animations hit the right row. Under
`prefers-reduced-motion: reduce`, every animation and transition is
effectively instant.

Not used: starfields, rockets flying along the path, confetti, looping glows,
shake on error.

## Accessibility

- Launch/Land and the body choice are real radio groups (segmented look).
- The step number is a real button with `aria-pressed` and a label ("Step 2:
  show fuel chain").
- Icon-only buttons have `aria-label`s. The spine SVG is decorative
  (`aria-hidden`); the rows are the accessible source of truth.
- Visible focus on every control: a 2px ink outline.
- Touch targets are at least 44px on touch screens.
- Colours that must be told apart also differ in lightness, not hue alone.

## Iconography

- Heroicons outline (shipped with Phoenix 1.8) for chrome: arrows, x-mark,
  exclamation-triangle (warning), x-circle (error), arrow-uturn-left (undo),
  sun / moon (theme).
- Custom 16px glyphs: launch (arc leaving a ground line) and land (arc meeting
  it); planet dots with a small mark (Earth meridian, Moon craters, Mars polar
  cap).
- No emoji, no mixing Unicode arrows with SVG icons.
