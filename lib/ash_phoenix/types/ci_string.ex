defimpl Phoenix.HTML.Safe, for: Ash.CiString do
  def to_iodata(%Ash.CiString{} = ci_string) do
    Phoenix.HTML.Safe.to_iodata(Ash.CiString.value(ci_string))
  end
end

defimpl Phoenix.Param, for: Ash.CiString do
  def to_param(ci_string) do
    Phoenix.Param.to_param(Ash.CiString.value(ci_string))
  end
end
