defmodule AshPhoenix.FilterForm.Predicate do
  @moduledoc """
  Represents an individual predicate appearing in a filter form.

  Predicates are grouped up in an `AshPhoenix.FilterForm` to create boolean
  filter statements.
  """

  defstruct [
    :id,
    :field,
    :value,
    :transform_errors,
    operator: :eq,
    params: %{},
    arguments: nil,
    negated?: false,
    path: [],
    errors: [],
    valid?: false
  ]

  def errors(predicate, transform_errors) do
    predicate.errors
    |> Enum.filter(fn
      error when is_exception(error) ->
        AshPhoenix.FormData.Error.impl_for(error)

      {_key, _value, _vars} ->
        true

      _ ->
        false
    end)
    |> Enum.flat_map(
      &AshPhoenix.FormData.Helpers.transform_predicate_error(
        predicate,
        &1,
        transform_errors
      )
    )
    |> Enum.map(fn
      {field, message, vars} ->
        vars =
          vars
          |> List.wrap()
          |> Enum.flat_map(fn {key, value} ->
            try do
              if is_integer(value) do
                [{key, value}]
              else
                [{key, to_string(value)}]
              end
            rescue
              _ ->
                []
            end
          end)

        {field, {message || "", vars}}
    end)
  end

  defimpl Phoenix.HTML.FormData do
    @impl true
    def to_form(predicate, opts) do
      hidden = [id: predicate.id]

      errors = AshPhoenix.FilterForm.Predicate.errors(predicate, opts[:transform_errors])

      %Phoenix.HTML.Form{
        source: predicate,
        impl: __MODULE__,
        id: opts[:id] || predicate.id,
        name: opts[:as] || predicate.id,
        errors: errors,
        data: predicate,
        params: predicate.params,
        hidden: hidden,
        options: Keyword.put_new(opts, :method, "GET")
      }
    end

    @impl true
    def to_form(form, phoenix_form, :arguments, _opts) do
      if form.arguments do
        [
          Phoenix.HTML.FormData.to_form(form.arguments,
            transform_errors: form.transform_errors,
            id: form.id <> "_arguments",
            as: phoenix_form.name <> "[arguments]"
          )
        ]
      else
        []
      end
    end

    def to_form(_, _, other, _) do
      raise "Invalid inputs_for name #{other}. Only :arguments is supported"
    end

    @impl true
    def input_value(form, phoenix_form, :arguments),
      do: to_form(form, phoenix_form, :arguments, [])

    def input_value(%{id: id}, _, :id), do: id
    def input_value(%{field: field}, _, :field), do: field
    def input_value(%{value: value}, _, :value), do: value
    def input_value(%{operator: operator}, _, :operator), do: operator
    def input_value(%{negated?: negated?}, _, :negated), do: negated?
    def input_value(%{path: path}, _, :path), do: Enum.join(path, ".")

    def input_value(_, _, _field) do
      nil

      # We can't raise here
      # raise "Invalid filter form field #{field}. Only :id, :negated, :operator, :field, :path, :value are supported"
    end

    @impl true
    def input_validations(_, _, _), do: []
  end
end
