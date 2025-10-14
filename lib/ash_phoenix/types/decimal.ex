# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs.contributors>
#
# SPDX-License-Identifier: MIT

unless Phoenix.HTML.Safe.impl_for(Decimal) do
  defimpl Phoenix.HTML.Safe, for: Decimal do
    defdelegate to_iodata(data), to: Decimal, as: :to_string
  end

  defimpl Phoenix.Param, for: Decimal do
    defdelegate to_param(data), to: Decimal, as: :to_string
  end
end
