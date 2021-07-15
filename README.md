# AshPhoenix

[![Elixir CI](https://github.com/ash-project/ash_phoenix/actions/workflows/elixir.yml/badge.svg)](https://github.com/ash-project/ash_phoenix/actions/workflows/elixir.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Coverage Status](https://coveralls.io/repos/github/ash-project/ash_phoenix/badge.svg?branch=main)](https://coveralls.io/github/ash-project/ash_phoenix?branch=main)
[![Hex version badge](https://img.shields.io/hexpm/v/ash_phoenix.svg)](https://hex.pm/packages/ash_phoenix)

See the online documentation for `AshPhoenix.LiveView` for the current set of utilities. This is a new integration, and doesn't do much. Currently, the only
thing that is offered are a few helpers for keeping query data live ins ide of live views. There is some experimental code here as well for passing an `Ash.Changeset` to Phoenix.HTML.form_for/4.

Roadmap:

- UI authorization utilities e.g `<%= if authorized_to_do?(resource, action, actor) do %>`
- Potentially helpers for easily connecting buttons to resource actions

```elixir
def deps do
  [
    {:ash_phoenix, "~> 0.4.23"}
  ]
end
```
