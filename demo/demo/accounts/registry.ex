defmodule Demo.Accounts.Registry do
  @moduledoc false
  use Ash.Registry, extensions: [Ash.Registry.ResourceValidations]

  entries do
    entry Demo.Accounts.User
  end
end
