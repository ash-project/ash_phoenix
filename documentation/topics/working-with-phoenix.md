# Working With Phoenix

The AshPhoenix plugin adds lots of helpers for working with Phoenix Liveview (and regular views).

{{mix_dep:ash_phoenix}}

## Whats in the box?

- {{link:ash_phoenix:module:AshPhoenix.Form}} - A form data structure for using resource actions with phoenix forms
- {{link:ash_phoenix:module:AshPhoenix.Form.Auto}} - Tools to automatically determine nested form structures based on calls `manage_relationship` for an action.
- {{link:ash_phoenix:module:AshPhoenix.FilterForm}} - A form data structure for building filter statements
- {{link:ash_phoenix:module:AshPhoenix.LiveView}} - Helpers for querying data and integrating changes
- {{link:ash_phoenix:module:AshPhoenix.SubdomainPlug}} - A plug to determine a tenant using subdomains for multitenancy
- {{link:ash_phoenix:module:AshPhoenix.FormData.Error}} - A protocol to allow errors to be rendered in forms
- `Phoenix.HTML.Safe` implementations for `Ash.CiString` and `Ash.NotLoaded`