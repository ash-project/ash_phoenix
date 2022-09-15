unless Phoenix.HTML.Safe.impl_for(Decimal) do
  defimpl Phoenix.HTML.Safe, for: Decimal do
    defdelegate to_iodata(data), to: Decimal, as: :to_string
  end

  defimpl Phoenix.Param, for: Decimal do
    defdelegate to_param(data), to: Decimal, as: :to_string
  end
end
