# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPhoenix.Test.DummyDomain do
  @moduledoc false
  use Ash.Domain, extensions: [AshPhoenix]

  resources do
    allow_unregistered? true
  end
end
