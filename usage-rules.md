<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->

# Rules for working with AshPhoenix

## Understanding AshPhoenix

AshPhoenix is a package for integrating Ash Framework with Phoenix Framework. It provides tools for integrating with Phoenix forms (`AshPhoenix.Form`), Phoenix LiveViews (`AshPhoenix.LiveView`), and more. AshPhoenix makes it seamless to use Phoenix's powerful UI capabilities with Ash's data management features.

## Best Practices

1. **Let the Resource guide the UI**: Your Ash resource configuration determines a lot about how forms and inputs will work. Well-defined resources with appropriate validations and changes make AshPhoenix more effective.

2. **Leverage code interfaces**: Define code interfaces on your domains for a clean and consistent API to call your resource actions.

3. **Update resources before editing**: When building forms for updating resources, load the resource with all required relationships using `Ash.load!/2` before creating the form.
