# AshPhoenix

[![Elixir CI](https://github.com/ash-project/ash_phoenix/actions/workflows/elixir.yml/badge.svg)](https://github.com/ash-project/ash_phoenix/actions/workflows/elixir.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Coverage Status](https://coveralls.io/repos/github/ash-project/ash_phoenix/badge.svg?branch=main)](https://coveralls.io/github/ash-project/ash_phoenix?branch=main)
[![Hex version badge](https://img.shields.io/hexpm/v/ash_phoenix.svg)](https://hex.pm/packages/ash_phoenix)

See the module documentation for more information:

- `AshPhoenix.LiveView`: for liveview querying utilities
- `AshPhoenix.Form`: Utilities for using forms with Ash changesets 

## Roadmap

- UI authorization utilities e.g `<%= if authorized_to_do?(resource, action, actor) do %>`
- Potentially helpers for easily connecting buttons to resource actions

```elixir
def deps do
  [
    {:ash_phoenix, "~> 0.7.7"}
  ]
end
```

## Contributors

Ash is made possible by its excellent community!

<a href="https://github.com/ash-project/ash_phoenix/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=ash-project/ash_phoenix" />
</a>

[Become a contributor](https://ash-hq.org/docs/guides/ash/latest/how_to/contribute.md)
