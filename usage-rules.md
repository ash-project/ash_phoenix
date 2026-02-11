<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->

# Rules for working with AshPhoenix

## Understanding AshPhoenix

AshPhoenix is a package for integrating Ash Framework with Phoenix Framework. It provides tools for integrating with Phoenix forms (`AshPhoenix.Form`), Phoenix LiveViews (`AshPhoenix.LiveView`), and more. AshPhoenix makes it seamless to use Phoenix's powerful UI capabilities with Ash's data management features.

## Debugging Form Submission

Errors on forms are only shown when they implement the `AshPhoenix.FormData.Error` protocol and have a `field` or `fields` set. 
Most Phoenix applications are set up to show errors for `<.input`s. This can some times lead to errors happening in the 
action that are not displayed because they don't implement the protocol, have field/fields, or for a field that is not shown
in the form.

To debug these situations, you can use `AshPhoenix.Form.raw_errors(form, for_path: :all)` on a failed form submission to see what
is going wrong, and potentially add custom error handling, or resolve whatever error is occurring. If the action has errors
that can go wrong that aren't tied to fields, you will need to detect those error scenarios and display that with some other UI,
like a flash message or a notice at the top/bottom of the form, etc.

If you want to see what errors the form will see (that implement the protocl and have fields) use 
`AshPhoenix.Form.errors(form, for_path: :all)`.

## Best Practices

1. **Let the Resource guide the UI**: Your Ash resource configuration determines a lot about how forms and inputs will work. Well-defined resources with appropriate validations and changes make AshPhoenix more effective.

2. **Leverage code interfaces**: Define code interfaces on your domains for a clean and consistent API to call your resource actions.

3. **Update resources before editing**: When building forms for updating resources, load the resource with all required relationships using `Ash.load!/2` before creating the form.
