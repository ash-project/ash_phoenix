defimpl Phoenix.HTML.Safe, for: Ash.CiString do
  def to_iodata(%Ash.CiString{} = ci_string) do
    Ash.CiString.value(ci_string)
  end
end
