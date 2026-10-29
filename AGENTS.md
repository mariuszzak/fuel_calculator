# AGENTS.md

Guidance for coding agents (and humans) working in this repository. This is the
only agent instruction file — there is no `CLAUDE.md`.

Companion documents:

- **Original challenge spec (source of truth for requirements):**
  [`docs/CHALLENGE.md`](docs/CHALLENGE.md), verbatim. Never edit it.
- `README.md` — project documentation for our app (setup, run, test,
  architecture).
- [`PRODUCT.md`](PRODUCT.md) — what we are building and the product decisions,
  with reasoning.
- [`DESIGN.md`](DESIGN.md) — visual and interaction design: themes and
  tokens, typography, layout, states, motion, accessibility. Applies to the
  app UI and to generated docs/HTML pages.
- `docs/phoenix-guidelines.md` — Phoenix 1.8 / LiveView usage rules generated
  by `phx.new`. **Read it before writing Phoenix code.** Where it conflicts with
  this file (e.g. its daisyUI and streams advice), this file wins.

---

## 1. Working agreement

1. **Decisions belong to the human.** Ask about every non-obvious design or
   product decision. Present options, pros/cons, UX impact and a
   recommendation. Do not silently pick.
2. **No commits without confirmation.** Prepare a commit after each meaningful
   stage (Conventional Commits, e.g. `feat(core): ...`), then wait for the
   human to review the diff and approve. Never add an agent as co-author.
3. **Never push.** The human pushes to `origin`.
4. **Reviews only on request.** Independent review agents (security,
   architecture, code quality, spec conformance) run only after an explicit
   "go ahead".
5. If you disagree with a rule here, say so — don't quietly work around it.
6. **No dangerous commands without explicit permission.** Ask first, stating
   the exact command and what it affects, and wait for a clear "yes" for
   *that* command (approval doesn't carry over to the next one). This
   includes:
   - Installing or upgrading global tools, Mix archives (`hex`, `phx_new`),
     language versions, or changing system/user config (mise, shell, global
     git config). Work in project or scratch directories instead.
   - Destructive local/git operations: `rm -rf`, `git reset --hard`,
     `git clean`, `git checkout -- .`, force operations, history rewrites,
     branch deletion.
   - Anything that publishes or sends data to an external service.

   Read-only commands (`git status`, `git diff`, `mix hex.info`, listing
   files) are fine.

## 2. Secrets

- Never read, print, log or commit secrets (`secret_key_base`, signing salts
  used in prod, any tokens). Redact them in any output.
- Production secrets come from environment variables in `config/runtime.exs`.
- `.env*` and similar files are git-ignored.

## 3. Architecture principles

- **Layered design with a well-tested, pure core.** The domain core has no
  I/O and knows nothing about Phoenix, LiveView, Ecto or HTML. A thin
  boundary turns raw input into validated structs. Phoenix/LiveView is a thin
  delivery layer.
- **Web never calls domain internals.** LiveViews and components call only
  the documented public context API (`FuelCalculator`). Internal modules are
  marked `@moduledoc false` and are not called across the boundary.
- **Wrap third-party libraries** behind our own module when they sit on a
  boundary we might want to replace or stub in tests. Our interface, our
  structs; the library is an implementation detail.
- **External input is untrusted.** Keep separate *raw* and *validated*
  structs. Only validated structs enter the core. **Never convert external
  strings to atoms** (`String.to_atom/1` is forbidden on external data; use
  `Ecto.Enum` or explicit pattern-matched mapping against a closed set).
- Prioritise maintainability, readability and idiomatic Elixir over
  performance.

## 4. Elixir code rules

### Structs, not bare maps / keyword lists

- Domain data, function params and options are structs. A public function's
  `@spec` must not use `map()`, `keyword()` or `Keyword.t()` for params;
  define a dedicated struct (`Params`, `Options`).
- Allowed exceptions: nested types like `[map()]`; typed map shapes like
  `%{required(:k) => v}`; test files; real external boundaries (form params,
  third-party library options, framework-expected shapes).
- Every struct is fully defined: `@type t :: %__MODULE__{...}` with every
  field typed, and required fields listed in `@enforce_keys`.
- **Construct structs via a public `new` function, not `%Foo{...}` literals.**
  Only the struct's own module builds it with `%__MODULE__{}`; everyone else
  calls `Foo.new(...)`. The constructor is the single place for defaults,
  normalisation and invariants.
  - `new/n` returns the struct directly when construction cannot fail (e.g.
    `FlightStep.new(:launch, %Planet{} = earth)`).
  - When input may be invalid, `new/n` returns
    `{:ok, %Foo{}} | {:error, %SomeError{}}`, optionally paired with `new!/n`
    that returns the struct or raises. Use `new!` only where invalid input is
    a programmer error (compile-time data such as planets and presets,
    tests) — never on external input.
  - `new`/`new!` **enforce field types with guards in the function head**, so
    type mismatches fail fast at the construction site:
    ```elixir
    def new(mass_kg, steps) when is_integer(mass_kg) and mass_kg > 0 and is_list(steps) do
      %__MODULE__{mass_kg: mass_kg, steps: steps}
    end
    ```
    Guard every field the type allows guarding (`is_binary/1`,
    `is_integer/1`, struct patterns, `in` for closed atom sets). Values that
    can't be expressed as guards are validated in the body and returned as an
    error struct.
  - `%Foo{}` is still used for **pattern matching** (`{:ok, %Foo{} = foo}`,
    function heads) — that is matching, not construction.
  - Struct updates (`%{foo | field: value}`) are fine inside the owning
    module; outside it prefer an intention-revealing function
    (`FlightPath.move_step(path, id, :up)`).
  - Test builders may call `new` with overrides; avoid raw literals in tests
    too, unless testing the constructor itself.

### Results

- Public functions that can fail return `{:ok, %SomeResult{}}` or
  `{:error, %SomeError{}}`.
- Public functions that cannot fail (pure computations on validated structs,
  e.g. `Fuel.for_mission/1`) return the result struct directly — no
  `{:ok, _}` wrapper and no dead error branch at call sites.
- Never return `{:error, :atom}`, `{:error, "string"}`, `{:error, {tag, data}}`,
  a bare map, a number or `nil` from a public function. Wrap reasons in an
  error struct, e.g. `{:error, Error.InvalidMission.new(errors)}`.
- Private `defp` helpers may use atoms internally; the public `def` converts
  them into structs.
- `nil` is allowed as a **struct field value** for genuinely optional data
  (typed explicitly, e.g. `selected_step_id: String.t() | nil`), never as a
  public function's return value.

### Pattern matching

- Match the struct in `{:ok, _}` patterns: `{:ok, %Mission{} = mission}`,
  `{:ok, %Mission{}}`, `{:ok, %Mission{} = _mission}`. Never `{:ok, mission}`,
  `{:ok, _}` or `{:ok, _mission}`.
- Match exhaustively in `case`, `with` and function heads. No catch-all `_ ->`
  hiding unconsidered cases.

### Framework expectations win

- If these rules conflict with what the framework expects, follow the
  framework, **add a short comment explaining the exception**, and mention it
  to the human.
- Agreed exceptions (already approved — still comment them in code):
  1. **LiveView callbacks** return framework shapes (`{:ok, socket}`,
     `{:noreply, socket}`); `handle_event/3` receives params as a map.
  2. **Function component `assigns` and socket assigns** are maps by
     framework design.
  3. **Forms** use `%Ecto.Changeset{}` via `to_form/1` as the framework
     expects. The context exposes a changeset only for form rendering
     (`change_mission/1`); its validating API still returns error structs.

### Validation of external input

- Raw → validated conversion uses **Ecto embedded schemas** (`ecto` +
  `phoenix_ecto`, no `ecto_sql`, no database). The changeset is an internal
  detail of the validator: public validating functions return
  `{:ok, %Validated{}}` or `{:error, %Error.InvalidMission{}}` (built from
  changeset errors).
- Use `Ecto.Enum` with values from the domain module (e.g. `Planet.ids()`)
  for closed sets — one whitelist, never arbitrary atoms.
- Bound untrusted input before processing it (string lengths, list sizes).

### Tooling

- `mix format`, `mix compile --warnings-as-errors`, `credo --strict` and
  `dialyzer` must pass.
- Credo: prefer an explicit, local `# credo:disable-for-next-line Check.Name`
  with a reason over global disables. Any global or per-directory disable
  (e.g. for tests) requires the human's approval.

## 5. Dependencies

- Ask before adding any third-party library.
- Prefer well-established, maintained libraries. Do a short maturity and
  security assessment (maintainers, release cadence, downloads, open
  advisories, transitive deps) before proposing.
- **7-day cooldown:** only use versions released at least 7 days ago — this
  applies to transitive deps resolved into `mix.lock` too.
  **Security exception:** a newer release may be used when it fixes a
  published advisory affecting the version we would otherwise use, but
  **always ask the human first** (show the advisory, fixed version and age),
  and note the exception next to the dependency in `mix.exs`.
- Check advisories with `mix hex.audit` and `mix deps.audit` whenever
  dependencies change.
- Target the latest stable Elixir / Erlang/OTP, pinned in `.tool-versions`
  (read by mise and asdf).

## 6. Testing

- Test behaviour, not implementation. Name tests by behaviour
  (`"returns 0 fuel when the formula goes negative"`).
- Arrange / Act / Assert structure, with the three parts separated by blank
  lines. Don't label them with `# Arrange` / `# Act` / `# Assert` comments.
- **Errors: assert concrete values, not wildcards.** Compare whole error
  results with `==` against the exact expected struct, built with its
  constructor, including error messages. Avoid `[_ | _]`, partial struct
  matches and `=~` on messages when the exact value is known; a pattern match
  is fine when the value is genuinely unpredictable (generated ids).
- **Success results: match only what the test is about.** Pattern-match the
  fields that matter for this behaviour (`%FuelReport{total_fuel_kg: 51_898}`);
  don't spell out unrelated fields.
- Shared helpers and builders (e.g. `mission(mass: 28_801, path: "launch earth, land moon")`)
  keep tests short and composable.
- Layers: pure unit tests and doctests for the core; property-based tests
  (StreamData) for invariants; boundary tests for raw → validated
  conversion; LiveView tests (`Phoenix.LiveViewTest` + LazyHTML) through
  rendered output and events, selecting elements by DOM id.

## 7. Documentation

- Docs are written for humans: short, concrete, easy to scan.
- Use Mermaid diagrams (well formatted, coloured via `classDef`) for flows
  and architecture. Link animated HTML pages from `docs/` where a picture
  helps.

## 8. Tasks

`justfile` holds common tasks (`just fmt`, `just lint`, `just test`,
`just ci`, …). `just` is optional; every recipe maps to plain `mix` commands.

---

## 9. Challenge

The spec is [`docs/CHALLENGE.md`](docs/CHALLENGE.md), the only source of
truth for requirements. Read it before starting any task; never edit it.
How we interpret its gaps (backward pass, zero or negative fuel, validation,
extras) is in [`PRODUCT.md`](PRODUCT.md). Anything not covered there is a
decision for the human.
