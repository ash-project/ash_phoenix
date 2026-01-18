# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPhoenix.Test.PostLink do
  @moduledoc false

  use Ash.Resource,
    domain: AshPhoenix.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  actions do
    default_accept :*
    defaults([:create, :update, :destroy])
  end

  relationships do
    belongs_to(:source_post, AshPhoenix.Test.Post, primary_key?: true, allow_nil?: false)
    belongs_to(:destination_post, AshPhoenix.Test.Post, primary_key?: true, allow_nil?: false)
  end
end
