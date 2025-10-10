# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshPhoenix.PlugTest do
  use ExUnit.Case

  describe "status/1" do
    test "for individual errors" do
      error = %Ash.Error.Query.NotFound{}
      assert 404 == Plug.Exception.status(error)
    end

    test "for top-level errors wrapping several errors" do
      error_custom_code = %Ash.Error.Query.NotFound{}

      # This is something that should never happen so will never have a custom status code
      error_default_code = %Ash.Error.Framework.SynchronousEngineStuck{}

      error = %Ash.Error.Invalid{errors: [error_custom_code]}
      assert 404 == Plug.Exception.status(error)

      error = %Ash.Error.Invalid{errors: [error_default_code]}
      assert 500 == Plug.Exception.status(error)

      # The highest error code is used when there are multiple child errors
      error = %Ash.Error.Invalid{errors: [error_default_code, error_custom_code]}
      assert 500 == Plug.Exception.status(error)
    end
  end
end
