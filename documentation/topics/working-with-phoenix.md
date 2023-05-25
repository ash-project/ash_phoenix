# Working With Phoenix

The AshPhoenix plugin adds lots of helpers for working with Phoenix Liveview (and regular views).

`{:ash_phoenix, "~> 1.2.14"}`

## Whats in the box?

- `AshPhoenix.Form` - A form data structure for using resource actions with phoenix forms
- `AshPhoenix.Form.Auto` - Tools to automatically determine nested form structures based on calls `manage_relationship` for an action.
- `AshPhoenix.FilterForm` - A form data structure for building filter statements
- `AshPhoenix.LiveView` - Helpers for querying data and integrating changes
- `AshPhoenix.SubdomainPlug` - A plug to determine a tenant using subdomains for multitenancy
- `AshPhoenix.FormData.Error` - A protocol to allow errors to be rendered in forms
- `Phoenix.HTML.Safe` implementations for `Ash.CiString` and `Ash.NotLoaded`