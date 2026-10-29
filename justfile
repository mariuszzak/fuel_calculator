# Common tasks. `just` is optional: every recipe is a plain mix command.

# List recipes
default:
    @just --list

# Install dependencies and build assets
setup:
    mix setup

# Start the dev server at http://localhost:4000
server:
    iex -S mix phx.server

# Format the code
fmt:
    mix format

# Check formatting, compile warnings and Credo (strict)
lint:
    mix lint

# Run the type checker (first run builds the PLT and takes a few minutes)
dialyzer:
    mix dialyzer

# Run the test suite; pass a path or flags, e.g. `just test test/fuel_calculator`
test *args:
    mix test {{args}}

# Run the test suite with coverage
cover:
    mix test --cover

# Check dependencies and code for known security issues
audit:
    mix audit

# Everything CI runs
ci: lint test dialyzer audit
