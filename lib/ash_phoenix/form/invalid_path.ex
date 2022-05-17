defmodule AshPhoenix.Form.InvalidPath do
  defexception [:path]

  def exception(opts) do
    %__MODULE__{path: opts[:path]}
  end

  def message(%{path: path}) do
    """
    Invalid or non-existent path: #{inspect(path)}
    """
  end
end
