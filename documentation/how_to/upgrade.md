# Upgrading from 1.0 to 2.0

There are a few major changes in 3.0 that you should be aware of that affect AshPhoenix's behavior.

1. You don't need to pass in the `domain` to your forms.

2. Extra inputs are no longer accepted by actions. This means that if you were using custom form parameters, you may run into issues. There is a new option when constructing forms, `skip_unknown_inputs: ["foo", "bar"]` that allows you to skip these, but they don't currently apply to nested forms. If you need this, or encounter any issues, please open an issue.

3. When calling `AshPhoenix.Form.params/1`, for the same reasons as above, it will no longer return the hidden fields from the form. If you need these, you can add the `hidden?: true` option to `AshPhoenix.Form.params/1`.
