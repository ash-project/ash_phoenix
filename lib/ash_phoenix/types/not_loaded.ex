# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defimpl Phoenix.HTML.Safe, for: Ash.NotLoaded do
  def to_iodata(_), do: ""
end

defimpl Phoenix.Param, for: Ash.NotLoaded do
  def to_param(_), do: ""
end
