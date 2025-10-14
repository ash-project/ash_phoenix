# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPhoenix.FormDataHelpersTest do
  use ExUnit.Case

  alias AshPhoenix.FormData.Helpers

  describe "transform_errors" do
    test "when InvalidQuery error is using field" do
      form = AshPhoenix.Test.User.form_to_create()
      message = "invalid email"

      errors =
        Helpers.transform_errors(
          form,
          [
            Ash.Error.Query.InvalidQuery.exception(
              field: :email,
              message: message,
              path: [:email]
            )
          ],
          [:email]
        )

      assert [email: {message, []}] == errors
    end
  end
end
