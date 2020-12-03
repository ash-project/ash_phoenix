defmodule AshPhoenix.Components.FilterElement2 do
  use Surface.Component

  defstruct [:attribute]

  def render(assigns) do
    ~H"""
    <div> Hello </div>
    """
  end
end
