# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defimpl Phoenix.HTML.Safe, for: Ash.NotLoaded do
  def to_iodata(_), do: ""
end

defimpl Phoenix.Param, for: Ash.NotLoaded do
  def to_param(_), do: ""
end
