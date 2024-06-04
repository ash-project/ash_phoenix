![Logo](https://github.com/ash-project/ash/blob/main/logos/cropped-for-header-black-text.png?raw=true#gh-light-mode-only)
![Logo](https://github.com/ash-project/ash/blob/main/logos/cropped-for-header-white-text.png?raw=true#gh-dark-mode-only)

![Elixir CI](https://github.com/ash-project/ash_phoenix/workflows/CI/badge.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Hex version badge](https://img.shields.io/hexpm/v/ash_phoenix.svg)](https://hex.pm/packages/ash_phoenix)
[![Hexdocs badge](https://img.shields.io/badge/docs-hexdocs-purple)](https://hexdocs.pm/ash_phoenix)

# AshPhoenix

Welcome! This is the package for integrating [Phoenix Framework](https://www.phoenixframework.org) and [Ash Framework](https://hexdocs.pm/ash). It provides tools for integrating with Phoenix forms (`AshPhoenix.Form`), Phoenix LiveViews (`AshPhoenix.LiveView`) and more.

## Installation

Add `ash_phoenix` to your list of dependencies in `mix.exs`:

```elixir
{:ash_phoenix, "~> 2.0.2"}
```

## Whats in the box?

- `AshPhoenix.Form` - A form data structure for using resource actions with phoenix forms
- `AshPhoenix.Form.Auto` - Tools to automatically determine nested form structures based on calls to `manage_relationship` for an action.
- `AshPhoenix.FilterForm` - A form data structure for building filter statements
- `AshPhoenix.LiveView` - Helpers for querying data and integrating changes
- `AshPhoenix.SubdomainPlug` - A plug to determine a tenant using subdomains for multitenancy
- `AshPhoenix.FormData.Error` - A protocol to allow errors to be rendered in forms
- `Phoenix.HTML.Safe` implementations for `Ash.CiString`, `Ash.NotLoaded` and `Decimal`
- `AshPhoenix.SubdomainPlug` for multitenant subdomain-based applications.
- `mix ash_phoenix.gen.live` for generating liveview modules
- `mix ash_phoenix.gen.html` for generating controllers and views

## Tutorials

- [Getting Started with Ash and Phoenix](documentation/tutorials/getting-started-with-ash-and-phoenix.md)

## Topics

- [Union Forms](documentation/topics/union-forms.md)
