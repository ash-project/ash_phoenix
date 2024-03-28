defmodule AshPhoenix.FilterForm.Arguments do
  @moduledoc "Represents the arguments to a calculation being filtered on"

  defstruct [:input, :params, :arguments, errors: []]

  def new(params, []) do
    %__MODULE__{input: %{}, params: params, arguments: [], errors: []}
  end

  def new(params, arguments) do
    {input, errors} = validate_arguments(arguments, params)
    %__MODULE__{input: input, params: params, arguments: arguments, errors: errors}
  end

  def validate_arguments(arguments, params) do
    Enum.reduce(arguments, {%{}, []}, fn argument, {arg_values, errors} ->
      value =
        default(
          Map.get(params, argument.name, Map.get(params, to_string(argument.name))),
          argument.default
        )

      cond do
        Ash.Expr.expr?(value) && argument.allow_expr? ->
          {Map.put(arg_values, argument.name, nil), errors}

        Ash.Expr.expr?(value) ->
          {arg_values, ["Argument #{argument.name} does not support expressions!" | errors]}

        is_nil(value) && argument.allow_nil? ->
          {Map.put(arg_values, argument.name, nil), errors}

        is_nil(value) ->
          {arg_values, ["Argument #{argument.name} is required" | errors]}

        !Map.get(params, argument.name, Map.get(params, to_string(argument.name))) && value ->
          {Map.put(arg_values, argument.name, value), errors}

        true ->
          case Ash.Type.cast_input(argument.type, value, argument.constraints) do
            {:ok, casted} ->
              {Map.put(arg_values, argument.name, casted), errors}

            {:error, error} ->
              {arg_values, [error | errors]}
          end
      end
    end)
  end

  defp default(nil, {module, function, args}), do: apply(module, function, args)
  defp default(nil, value) when is_function(value, 0), do: value.()
  defp default(nil, value), do: value
  defp default(value, _), do: value

  def errors(arguments, transform_errors) do
    arguments.errors
    |> Enum.filter(fn
      error when is_exception(error) ->
        AshPhoenix.FormData.Error.impl_for(error)

      {_key, _value, _vars} ->
        true

      _ ->
        false
    end)
    |> Enum.flat_map(
      &AshPhoenix.FormData.Helpers.transform_arguments_error(
        arguments,
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
    def to_form(arguments, opts) do
      errors = AshPhoenix.FilterForm.Arguments.errors(arguments, opts[:transform_errors])

      %Phoenix.HTML.Form{
        source: arguments,
        impl: __MODULE__,
        id: opts[:id],
        name: opts[:as],
        errors: errors,
        data: arguments,
        params: arguments.params,
        hidden: [],
        options: Keyword.put_new(opts, :method, "GET")
      }
    end

    @impl true
    def to_form(form, phoenix_form, :arguments, _opts) do
      [
        Phoenix.HTML.FormData.to_form(form.source.arguments,
          transform_errors: form.transform_errors,
          as: phoenix_form.name <> "[arguments]"
        )
      ]
    end

    def to_form(_, _, other, _) do
      raise "Invalid inputs_for name #{other}. Only :arguments is supported"
    end

    @impl true
    def input_value(arguments, phoenix_form, :arguments) do
      to_form(arguments, phoenix_form, :arguments, [])
    end

    def input_value(arguments, _, name) do
      if Enum.find(arguments.arguments, &(&1.name == name)) do
        Map.get(
          arguments.input,
          name,
          Map.get(arguments.params, name, Map.get(arguments.params, to_string(name)))
        )
      else
        raise "Invalid filter form field #{name}. Only #{Enum.map_join(arguments.arguments, ", ", &inspect(&1.name))} are supported."
      end
    end

    @impl true
    def input_validations(_, _, _), do: []
  end
end
