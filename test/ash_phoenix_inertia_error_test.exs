defmodule AshPhoenixTest.Inertia.ErrorsTest do
  use ExUnit.Case
  doctest AshPhoenix.Inertia.Error

  alias AshPhoenix.Inertia.Error

  describe "default_message_func/1" do
    test "handles string interpolation with regular string values" do
      message = "The field %{field} must match %{pattern}"
      vars = [field: "code", pattern: "alphanumeric"]

      result = Error.default_message_func({message, vars})

      assert result == "The field code must match alphanumeric"
    end

    test "handles string interpolation with regex values" do
      message = "The field %{field} must match %{pattern}"
      regex = ~r/^[A-Za-z0-9]+$/
      vars = [field: "code", pattern: regex]

      result = Error.default_message_func({message, vars})

      assert result == "The field code must match ^[A-Za-z0-9]+$"
    end

    test "handles mixed string and regex values" do
      message = "Field %{field} with value %{value} must match pattern %{pattern}"
      regex = ~r/^\d{3}-\d{4}$/
      vars = [field: "phone", value: "123-45678", pattern: regex]

      result = Error.default_message_func({message, vars})

      assert result == "Field phone with value 123-45678 must match pattern ^\\d{3}-\\d{4}$"
    end

    test "handles complex regex patterns" do
      message = "Invalid format: %{pattern}"
      regex = ~r/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/
      vars = [pattern: regex]

      result = Error.default_message_func({message, vars})

      assert result == "Invalid format: ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
    end

    test "handles nil vars" do
      message = "This is a simple message"

      result = Error.default_message_func({message, nil})

      assert result == "This is a simple message"
    end

    test "handles empty vars list" do
      message = "This is a simple message"

      result = Error.default_message_func({message, []})

      assert result == "This is a simple message"
    end

    test "handles integer values in vars" do
      message = "Must be at least %{min} characters"
      vars = [min: 8]

      result = Error.default_message_func({message, vars})

      assert result == "Must be at least 8 characters"
    end

    test "handles atom values in vars" do
      message = "Status is %{status}"
      vars = [status: :invalid]

      result = Error.default_message_func({message, vars})

      assert result == "Status is invalid"
    end

    test "handles multiple occurrences of the same variable" do
      message = "The %{field} field is required. Please provide %{field}."
      vars = [field: "email"]

      result = Error.default_message_func({message, vars})

      assert result == "The email field is required. Please provide email."
    end

    test "preserves message when variable key is not found" do
      message = "The field %{field} is invalid but %{unknown} is not replaced"
      vars = [field: "username"]

      result = Error.default_message_func({message, vars})

      assert result == "The field username is invalid but %{unknown} is not replaced"
    end

    test "handles regex with flags" do
      message = "Pattern: %{pattern}"
      regex = ~r/test/i
      vars = [pattern: regex]

      result = Error.default_message_func({message, vars})

      assert result == "Pattern: test"
    end

    test "handles regex with unicode flag" do
      message = "Pattern: %{pattern}"
      regex = ~r/café/u
      vars = [pattern: regex]

      result = Error.default_message_func({message, vars})

      assert result == "Pattern: café"
    end
  end

  describe "to_errors/2" do
    test "formats validation errors with regex patterns correctly" do
      # Simulate an Ash validation error with a regex pattern
      error = %Ash.Error.Changes.InvalidAttribute{
        field: :code,
        message: "must match %{match}",
        vars: [match: ~r/^[A-Za-z0-9]+$/],
        path: []
      }

      errors = [error]
      result = Error.to_errors(errors, &Error.default_message_func/1)

      assert result == %{
               "code" => "must match ^[A-Za-z0-9]+$"
             }
    end

    test "formats nested form errors with regex patterns" do
      error = %Ash.Error.Changes.InvalidAttribute{
        field: :postal_code,
        message: "must match postal code format %{pattern}",
        vars: [pattern: ~r/^\d{5}(-\d{4})?$/],
        path: [:address]
      }

      errors = [error]
      result = Error.to_errors(errors, &Error.default_message_func/1)

      assert result == %{
               "address.postal_code" => "must match postal code format ^\\d{5}(-\\d{4})?$"
             }
    end

    test "handles multiple errors with mixed variable types" do
      errors = [
        %Ash.Error.Changes.InvalidAttribute{
          field: :email,
          message: "must match %{pattern}",
          vars: [pattern: ~r/^[\w.%+-]+@[\w.-]+\.[A-Z]{2,}$/i],
          path: []
        },
        %Ash.Error.Changes.InvalidAttribute{
          field: :age,
          message: "must be at least %{min}",
          vars: [min: 18],
          path: []
        }
      ]

      result = Error.to_errors(errors, &Error.default_message_func/1)

      assert result == %{
               "email" => "must match ^[\\w.%+-]+@[\\w.-]+\\.[A-Z]{2,}$",
               "age" => "must be at least 18"
             }
    end

    test "does not raise Protocol.UndefinedError when regex is in vars (issue #410)" do
      # This test specifically reproduces the bug from issue #410
      # where a Protocol.UndefinedError was raised when trying to convert
      # a Regex to a string using String.Chars protocol

      error = %Ash.Error.Changes.InvalidAttribute{
        field: :code,
        message: "must match %{match}",
        vars: [match: ~r/^[A-Za-z0-9]+$/],
        path: []
      }

      errors = [error]

      # This should not raise an error
      assert_nothing_raised = fn ->
        Error.to_errors(errors, &Error.default_message_func/1)
      end

      # Execute without raising
      result = assert_nothing_raised.()

      # And it should properly format the regex
      assert result == %{
               "code" => "must match ^[A-Za-z0-9]+$"
             }
    end

    test "handles the exact scenario from issue #410" do
      # Simulating the exact validation from the bug report:
      # validate match(:code, "^[A-Za-z0-9]+$")
      # When code contains "@" character

      error = %Ash.Error.Changes.InvalidAttribute{
        field: :code,
        message: "must match %{match}",
        vars: [match: ~r/^[A-Za-z0-9]+$/],
        path: []
      }

      errors = [error]

      # Before the fix, this would raise:
      # ** (Protocol.UndefinedError) protocol String.Chars not implemented for ~r/^[A-Za-z0-9]+$/
      result = Error.to_errors(errors, &Error.default_message_func/1)

      assert result == %{
               "code" => "must match ^[A-Za-z0-9]+$"
             }

      # Verify the message is properly formatted and readable
      assert is_binary(result["code"])
      refute result["code"] =~ "Regex"
      assert result["code"] =~ "^[A-Za-z0-9]+$"
    end
  end
end
