# Fuel Calculator

A Phoenix LiveView app that calculates the fuel a spacecraft needs to launch
from and land on Earth, the Moon and Mars. Enter the equipment mass, build a
flight path, and the total updates as you type, with every step's fuel, the
mass each burn has to move, and the "fuel needs fuel" chain on screen.

Built for the [Elixir full-stack challenge](docs/CHALLENGE.md).

## The one thing to get right

Fuel adds mass, so the fuel needs fuel of its own, and so on until the
formula gives zero. That much is in the spec. The less obvious part: **every
step also carries the fuel for all the steps after it**. The launch from
Earth lifts the fuel needed to land on the Moon, launch again and land back
home. So the calculation runs from the last step back to the first.

| Apollo 11, 28,801 kg | Per step, dry mass only | Last step first (correct) |
|---|---|---|
| Launch from Earth | 19,772 kg | carries 47,711 kg → **32,988 kg** |
| Land on the Moon | 1,535 kg | carries 45,249 kg → **2,462 kg** |
| Launch from the Moon | 2,024 kg | carries 42,248 kg → **3,001 kg** |
| Land on Earth | 13,447 kg | carries 28,801 kg → **13,447 kg** |
| **Total** | 36,778 kg ✗ | **51,898 kg** ✓ (matches the spec) |

All three spec missions (51,898, 33,388 and 212,161 kg) are acceptance tests
and one-click presets in the app.

```mermaid
flowchart RL
    classDef step fill:#EDE8FF,stroke:#7354E8,color:#1F1B24
    classDef ship fill:#F1EFEC,stroke:#88817B,color:#1F1B24
    S4["4 · Land on Earth<br/>carries 28,801 kg<br/>needs 13,447 kg"]:::step --> S3
    S3["3 · Launch from Moon<br/>carries 42,248 kg<br/>needs 3,001 kg"]:::step --> S2
    S2["2 · Land on Moon<br/>carries 45,249 kg<br/>needs 2,462 kg"]:::step --> S1
    S1["1 · Launch from Earth<br/>carries 47,711 kg<br/>needs 32,988 kg"]:::step
    Ship(["Ship 28,801 kg"]):::ship --> S4
```

The arithmetic is exact: gravity is stored in thousandths and the formula
uses integer floor division. Floating point is *not* good enough here: the
mass a burn carries can reach about 4×10¹³ kg, where floats round wrongly
(there's a regression test for it).

## Running it

Requirements: Erlang/OTP 29.1.2 and Elixir 1.20.4 (pinned in
`.tool-versions`; `mise install` or `asdf install` picks them up).

```sh
mix setup          # dependencies and assets
mix phx.server     # or: iex -S mix phx.server
```

Then open <http://localhost:4000>.

With [`just`](https://github.com/casey/just) installed, `just` lists the
shortcuts; every recipe is a plain `mix` command underneath.

| Task | `mix` | `just` |
|---|---|---|
| Install and build assets | `mix setup` | `just setup` |
| Dev server | `iex -S mix phx.server` | `just server` |
| Format | `mix format` | `just fmt` |
| Lint (format check, warnings as errors, Credo strict) | `mix lint` | `just lint` |
| Tests | `mix test` | `just test` |
| Tests with coverage | `mix test --cover` | `just cover` |
| Type check | `mix dialyzer` | `just dialyzer` |
| Security (Hex, advisories, Sobelow) | `mix audit` | `just audit` |
| Everything CI runs | | `just ci` |

## Architecture

Three layers with one public door. The web layer only calls the
`FuelCalculator` context and reads the structs it returns; input is
validated at the boundary; the core is pure and has no Phoenix or Ecto in it.

```mermaid
flowchart LR
    classDef web fill:#EDE8FF,stroke:#7354E8,color:#1F1B24
    classDef ctx fill:#FBFAF8,stroke:#5A5560,color:#1F1B24
    classDef bnd fill:#FDF0D5,stroke:#B7791F,color:#1F1B24
    classDef core fill:#E3F1E8,stroke:#2E7D4F,color:#1F1B24

    subgraph Web["Web · FuelCalculatorWeb"]
        LV[MissionLive]:::web --> C[Mission components]:::web
        C --> SP[Spine geometry]:::web
    end
    LV --> API[FuelCalculator<br/>public API]:::ctx
    subgraph Boundary["Boundary · untrusted → validated"]
        MP[MissionParams<br/>Ecto embedded schema]:::bnd
        PE[ParamsEditor<br/>add · move · remove]:::bnd
    end
    subgraph Core["Core · pure"]
        F[Fuel<br/>backward pass]:::core
        FP[FlightPath<br/>warnings · next step]:::core
        T[Planet · FlightStep · Mission<br/>FuelReport · Preset]:::core
    end
    API --> MP
    API --> PE
    API --> F
    API --> FP
    MP --> T
    F --> T
    FP --> T
```

One edit, end to end:

```mermaid
sequenceDiagram
    autonumber
    participant U as Browser
    participant LV as MissionLive
    participant API as FuelCalculator
    participant MP as MissionParams
    participant Core as Fuel · FlightPath
    U->>LV: types a mass / picks a planet (phx-change)<br/>or clicks add · move · remove (phx-click)
    LV->>API: evaluate(params)
    API->>MP: step limit, cast, validate (whitelists, mass parser)
    MP-->>API: valid steps + Mission, or InvalidMission
    API->>Core: fuel report, path warnings, next step
    Core-->>API: FuelReport, [PathWarning], FlightStep
    API-->>LV: %Evaluation{}
    LV-->>U: re-render: total, steps, spine, warnings
```

| Module | Role |
|---|---|
| `FuelCalculator` | The public API: `evaluate/1`, `build_mission/1`, `fuel_report/1`, presets and the step-editing functions |
| `FuelCalculator.Fuel` | The formula and the backward pass, in exact integers |
| `FuelCalculator.FlightPath` | Path continuity warnings (with two fixes each) and the suggested next step |
| `FuelCalculator.MissionParams` | Raw form input → validated `Mission`; the only place strings become atoms (through `Ecto.Enum`) |
| `FuelCalculatorWeb.MissionLive` | The screen: keeps the form params, handles events, renders components |
| `FuelCalculatorWeb.Mission.*Components` | Small function components: spacecraft inputs, summary, flight path, spine, warnings, undo |

## Tests

About 140 tests: unit tests and doctests for the core (including the
zero-fuel threshold for every action and planet), acceptance tests for the
three spec missions, StreamData properties (fuel never negative, more mass
never needs less fuel, each step carries the fuel for later steps, agreement
with a naive reference), boundary tests for every validation message and
tampered input (no atoms are created from user input), and LiveView tests
that drive the real form and buttons.

## Documents

- [`docs/CHALLENGE.md`](docs/CHALLENGE.md): the original spec, verbatim.
- [`PRODUCT.md`](PRODUCT.md): how we read the spec and every product
  decision, with reasoning.
- [`DESIGN.md`](DESIGN.md): themes, tokens, measured contrast, layout,
  states, motion and accessibility.
- [`AGENTS.md`](AGENTS.md): engineering rules for anyone (or any agent)
  working on the code.
- [`docs/phoenix-guidelines.md`](docs/phoenix-guidelines.md): Phoenix 1.8 /
  LiveView usage rules generated by `phx.new`.

Dependencies follow a 7-day release cooldown; exceptions for security or
OTP 29 compatibility fixes are commented next to each dependency in
`mix.exs`.
