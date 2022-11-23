errors = [
  {Ash.Error.Invalid.InvalidPrimaryKey, 400},
  {Ash.Error.Query.InvalidArgument, 400},
  {Ash.Error.Query.InvalidFilterValue, 400},
  {Ash.Error.Query.NotFound, 404}
]

# Individual errors can have their own status codes that will propagate to the top-level
# wrapper error
for {module, status_code} <- errors do
  defimpl Plug.Exception, for: module do
    def status(_exception), do: unquote(status_code)
    def actions(_exception), do: []
  end
end

# Top-level Ash errors will use the highest status code of all of the wrapped child errors
defimpl Plug.Exception,
  for: [Ash.Error.Invalid, Ash.Error.Forbidden, Ash.Error.Framework, Ash.Error.Unknown] do
  def status(%{errors: errors} = _exception) do
    errors
    |> Enum.map(&Plug.Exception.status/1)
    |> Enum.max()
  end

  def actions(_exception), do: []
end
