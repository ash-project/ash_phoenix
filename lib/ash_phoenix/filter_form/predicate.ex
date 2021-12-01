defmodule AshPhoenix.FilterForm.Predicate do
  @moduledoc """
  An experimental tool to build forms that can produce an `Ash.Filter`.
  """

  defstruct [
    :id,
    :field,
    :value,
    operator: :eq,
    params: %{},
    negated?: false,
    errors: [],
    valid?: false
  ]

  defimpl Phoenix.HTML.FormData do
    @impl true
    def to_form(predicate, opts) do
      hidden = [id: predicate.id]

      %Phoenix.HTML.Form{
        source: predicate,
        impl: __MODULE__,
        id: predicate.id,
        name: predicate.id,
        errors: [],
        data: predicate,
        params: predicate.params,
        hidden: hidden,
        options: Keyword.put_new(opts, :method, "GET")
      }
    end

    @impl true
    def input_type(_, _, _), do: :text_input

    @impl true
    def to_form(_, _, _, _), do: []

    @impl true
    def input_value(%{field: field}, _, :field), do: field
    def input_value(%{value: value}, _, :value), do: value
    def input_value(%{operator: operator}, _, :operator), do: operator
    def input_value(%{negated?: negated?}, _, :negated), do: negated?

    def input_value(_, _, field) do
      raise "Invalid filter form field #{field}. Only :negated, :operator, :field and :value are supported"
    end

    @impl true
    def input_validations(_, _, _), do: []
  end
end
