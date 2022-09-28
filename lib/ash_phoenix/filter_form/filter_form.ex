defmodule AshPhoenix.FilterForm do
  defstruct [
    :id,
    :resource,
    :transform_errors,
    name: "filter",
    valid?: false,
    negated?: false,
    params: %{},
    components: [],
    operator: :and,
    remove_empty_groups?: false
  ]

  alias AshPhoenix.FilterForm.Predicate
  require Ash.Query

  @new_opts [
    params: [
      type: :any,
      doc: "Initial parameters to create the form with",
      default: %{}
    ],
    as: [
      type: :string,
      default: "filter",
      doc: "Set the parameter name for the form."
    ],
    transform_errors: [
      type: :any,
      doc: """
      Allows for manual manipulation and transformation of errors.

      If possible, try to implement `AshPhoenix.FormData.Error` for the error (if it as a custom one, for example).
      If that isn't possible, you can provide this function which will get the predicate and the error, and should
      return a list of ash phoenix formatted errors, e.g `[{field :: atom, message :: String.t(), substituations :: Keyword.t()}]`
      """
    ],
    remove_empty_groups?: [
      type: :boolean,
      doc: """
      If true (the default), then any time a group would be made empty by removing a group or predicate, it is removed instead.

      An empty form can still be added, this only affects a group if its last component is removed.
      """,
      default: false
    ]
  ]

  @moduledoc """
  Create a new filter form.

  Options:
  #{Spark.OptionsHelpers.docs(@new_opts)}
  """
  def new(resource, opts \\ []) do
    opts = Spark.OptionsHelpers.validate!(opts, @new_opts)
    params = opts[:params]

    params = sanitize_params(params)

    params =
      if is_predicate?(params) do
        %{
          "operator" => "and",
          "id" => Ash.UUID.generate(),
          "components" => %{"0" => params}
        }
      else
        params
      end

    form = %__MODULE__{
      id: params["id"],
      name: opts[:as] || "filter",
      resource: resource,
      params: params,
      remove_empty_groups?: opts[:remove_empty_groups?],
      operator: to_existing_atom(params["operator"] || :and)
    }

    %{
      form
      | components:
          parse_components(form, params["components"],
            remove_empty_groups?: opts[:remove_empty_groups?]
          )
    }
    |> set_validity()
  end

  @doc """
  Updates the filter with the provided input and validates it.

  At present, no validation actually occurs, but this will eventually be added.
  """
  def validate(form, params \\ %{}) do
    params = sanitize_params(params)

    params =
      if is_predicate?(params) do
        %{
          "operator" => "and",
          "id" => Ash.UUID.generate(),
          "components" => %{"0" => params}
        }
      else
        params
      end

    %{
      form
      | params: params,
        components: validate_components(form, params["components"]),
        operator: to_existing_atom(params["operator"] || :and)
    }
    |> set_validity()
  end

  @doc """
  Returns a filter expression that can be provided to Ash.Query.filter/2

  To add this to a query, remember to use `^`, for example:
  ```elixir
  filter = AshPhoenix.FilterForm.to_filter_expression(form)

  Ash.Query.filter(MyApp.Post, ^filter)
  ```

  Alternatively, you can use the shorthand: `filter/2` to apply the expression directly to a query.
  """
  def to_filter_expression(form) do
    if form.valid? do
      case do_to_filter_expression(form, form.resource) do
        {:ok, expr} ->
          {:ok, expr}

        {:error, form} ->
          {:error, form}
      end
    else
      {:error, form}
    end
  end

  @doc """
  Same as `to_filter/1`
  """
  def to_filter!(form) do
    case to_filter_expression(form) do
      {:ok, filter} ->
        filter

      {:error, form} ->
        error =
          form
          |> errors()
          |> Enum.map(fn
            {key, message, vars} ->
              "#{key}: #{AshPhoenix.replace_vars(message, vars)}"

            other ->
              other
          end)
          |> Ash.Error.to_error_class()

        raise error
    end
  end

  @doc """
  Returns a flat list of all errors on all predicates in the filter.
  """
  def errors(form, opts \\ [])

  def errors(%__MODULE__{components: components, transform_errors: transform_errors}, opts) do
    Enum.flat_map(
      components,
      &errors(&1, Keyword.put_new(opts, :handle_errors, transform_errors))
    )
  end

  def errors(%Predicate{} = predicate, opts),
    do: AshPhoenix.FilterForm.Predicate.errors(predicate, opts[:transform_errors])

  defp do_to_filter_expression(%__MODULE__{components: []}, _), do: {:ok, true}

  defp do_to_filter_expression(
         %__MODULE__{components: components, operator: operator, negated?: negated?} = form,
         resource
       ) do
    {filters, components, errors?} =
      Enum.reduce(components, {[], [], false}, fn component, {filters, components, errors?} ->
        case do_to_filter_expression(component, resource) do
          {:ok, component_filter} ->
            {filters ++ [component_filter], components ++ [component], errors?}

          {:error, component} ->
            {filters, components ++ [component], true}
        end
      end)

    if errors? do
      {:error, %{form | components: components}}
    else
      expr =
        Enum.reduce(filters, nil, fn component_as_filter, acc ->
          if acc do
            Ash.Query.BooleanExpression.new(operator, acc, component_as_filter)
          else
            component_as_filter
          end
        end)

      if negated? do
        {:ok, Ash.Query.Not.new(expr)}
      else
        {:ok, expr}
      end
    end
  end

  defp do_to_filter_expression(
         %Predicate{
           field: field,
           value: value,
           operator: operator,
           negated?: negated?,
           path: path
         } = predicate,
         resource
       ) do
    ref = Ash.Query.expr(ref(^field, ^path))

    expr =
      if Ash.Filter.get_operator(operator) do
        {:ok, %Ash.Query.Call{name: operator, args: [ref, value], operator?: true}}
      else
        if Ash.Filter.get_function(operator, resource, true) do
          {:ok, %Ash.Query.Call{name: operator, args: [ref, value]}}
        else
          {:error, {:operator, "No such function or operator #{operator}", []}}
        end
      end

    case expr do
      {:ok, expr} ->
        if negated? do
          {:ok, Ash.Query.Not.new(expr)}
        else
          {:ok, expr}
        end

      {:error, error} ->
        {:error, %{predicate | errors: predicate.errors ++ [error]}}
    end
  end

  @doc """
  Converts the form into a filter, and filters the provided query or resource with that filter.
  """
  def filter(query, form) do
    case to_filter_expression(form) do
      {:ok, filter} ->
        {:ok, Ash.Query.do_filter(query, filter)}

      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Same as `filter/2` but raises on errors.
  """
  def filter!(query, form) do
    Ash.Query.do_filter(query, to_filter!(form))
  end

  defp sanitize_params(params) do
    if is_predicate?(params) do
      field =
        case params[:field] || params["field"] do
          nil -> nil
          field -> to_string(field)
        end

      path =
        case params[:path] || params["path"] do
          nil -> nil
          path when is_list(path) -> Enum.join(path, ".")
          path when is_binary(path) -> path
        end

      %{
        "id" => params[:id] || params["id"] || Ash.UUID.generate(),
        "operator" => to_string(params[:operator] || params["operator"] || "eq"),
        "negated" => params[:negated] || params["negated"] || false,
        "field" => field,
        "value" => params[:value] || params["value"],
        "path" => path
      }
    else
      components = params[:components] || params["components"] || []

      components =
        if is_list(components) do
          components
          |> Enum.with_index()
          |> Map.new(fn {value, index} ->
            {to_string(index), value}
          end)
        else
          if is_map(components) do
            Map.new(components, fn {key, value} ->
              {key, sanitize_params(value)}
            end)
          end
        end

      %{
        "id" => params[:id] || params["id"] || Ash.UUID.generate(),
        "operator" => to_string(params[:operator] || params["operator"] || "and"),
        "negated" => params[:negated] || params["negated"] || false,
        "components" => components || %{}
      }
    end
  end

  defp parse_components(parent, component_params, form_opts) do
    component_params
    |> Kernel.||(%{})
    |> Enum.sort_by(fn {key, _value} ->
      String.to_integer(key)
    end)
    |> Enum.map(&parse_component(parent, &1, form_opts))
  end

  defp parse_component(parent, {key, params}, form_opts) do
    if is_predicate?(params) do
      # Eventually, components may have references w/ paths
      # also, we should validate references here
      new_predicate(params, parent)
    else
      params = Map.put_new(params, "id", Ash.UUID.generate())

      new(
        parent.resource,
        Keyword.merge(form_opts, params: params, as: parent.name <> "[components][#{key}]")
      )
    end
  end

  defp new_predicate(params, form) do
    {path, field} = parse_path_and_field(params, form)

    predicate = %AshPhoenix.FilterForm.Predicate{
      id: params["id"],
      field: field,
      value: params["value"],
      path: path,
      params: params,
      negated?: negated?(params),
      operator: to_existing_atom(params["operator"] || :eq)
    }

    %{predicate | errors: predicate_errors(predicate, form.resource)}
  end

  defp parse_path_and_field(params, form) do
    path = parse_path(params)
    field = to_existing_atom(params["field"])

    extended_path = path ++ [field]

    case Ash.Resource.Info.related(form.resource, extended_path) do
      nil -> {path, field}
      _ -> {extended_path, nil}
    end
  end

  defp parse_path(params) do
    path = params[:path] || params["path"]

    case path do
      "" ->
        []

      nil ->
        []

      path when is_list(path) ->
        Enum.map(path, &to_existing_atom/1)

      path ->
        path
        |> String.split(".")
        |> Enum.map(&to_existing_atom/1)
    end
  end

  defp negated?(params) do
    params["negated"] in [true, "true"]
  end

  defp validate_components(form, component_params) do
    form_without_components = %{form | components: []}

    component_params
    |> Enum.sort_by(fn {key, _} ->
      String.to_integer(key)
    end)
    |> Enum.map(&validate_component(form_without_components, &1, form.components))
  end

  defp validate_component(form, {key, params}, current_components) do
    id = params[:id] || params["id"]

    match_component =
      id && Enum.find(current_components, fn %{id: component_id} -> component_id == id end)

    if match_component do
      case match_component do
        %__MODULE__{} ->
          validate(match_component, params)

        %Predicate{} ->
          new_predicate(params, form)
      end
    else
      if is_predicate?(params) do
        new_predicate(params, form)
      else
        params = Map.put_new(params, "id", Ash.UUID.generate())

        new(form.resource,
          params: params,
          as: form.name <> "[components][#{key}]",
          remove_empty_groups?: form.remove_empty_groups?
        )
      end
    end
  end

  defp is_predicate?(params) do
    [:field, :value, "field", "value"] |> Enum.any?(&Map.has_key?(params, &1))
  end

  defp to_existing_atom(value) when is_atom(value), do: value

  defp to_existing_atom(value) do
    String.to_existing_atom(value)
  rescue
    _ -> value
  end

  @doc """
  Returns the minimal set of params (at the moment just strips ids) for use in a query string.
  """
  def params_for_query(form) do
    do_params_for_query(form.params)
  end

  defp do_params_for_query(params) do
    if is_predicate?(params) do
      Map.delete(params, "id")
    else
      params =
        case params["components"] do
          components when is_map(components) ->
            new_components =
              Map.new(components, fn {key, value} ->
                {key, do_params_for_query(value)}
              end)

            Map.put(params, "components", new_components)

          _ ->
            Map.delete(params, "components")
        end

      Map.delete(params, "id")
    end
  end

  @doc "Returns the list of available predicates for the given resource, which may be functions or operators."
  def predicates(resource) do
    resource
    |> Ash.DataLayer.data_layer()
    |> Ash.DataLayer.functions()
    |> Enum.concat(Ash.Filter.builtin_functions())
    |> Enum.filter(fn function ->
      try do
        struct(function).__predicate__? && Enum.any?(function.args, &match?([_, _], &1))
      rescue
        _ -> false
      end
    end)
    |> Enum.concat(Ash.Filter.builtin_predicate_operators())
    |> Enum.map(fn function_or_operator ->
      function_or_operator.name()
    end)
  end

  @doc "Returns the list of available fields, which may be attributes, calculations, or aggregates."
  def fields(resource) do
    resource
    |> Ash.Resource.Info.public_aggregates()
    |> Enum.concat(Ash.Resource.Info.public_calculations(resource))
    |> Enum.concat(Ash.Resource.Info.public_attributes(resource))
    |> Enum.map(& &1.name)
  end

  @add_predicate_opts [
    to: [
      type: :string,
      doc:
        "The group id to add the predicate to. If not set, will be added to the top level group."
    ],
    return_id?: [
      type: :boolean,
      default: false,
      doc: "If set to `true`, the function returns `{form, predicate_id}`"
    ],
    path: [
      type: {:or, [:string, {:list, {:or, [:string, :atom]}}]},
      doc: "The relationship path to apply the predicate to"
    ]
  ]

  @doc """
  Add a predicate to the filter.

  Options:

  #{Spark.OptionsHelpers.docs(@add_predicate_opts)}
  """
  def add_predicate(form, field, operator_or_function, value, opts \\ []) do
    opts = Spark.OptionsHelpers.validate!(opts, @add_predicate_opts)

    predicate_id = Ash.UUID.generate()

    predicate_params = %{
      "id" => predicate_id,
      "field" => field,
      "value" => value,
      "operator" => operator_or_function
    }

    predicate_params =
      if opts[:path] do
        Map.put(predicate_params, "path", opts[:path])
      else
        predicate_params
      end

    predicate =
      new_predicate(
        predicate_params,
        form
      )

    new_form =
      if opts[:to] && opts[:to] != form.id do
        set_validity(%{
          form
          | components: Enum.map(form.components, &do_add_predicate(&1, opts[:to], predicate))
        })
      else
        set_validity(%{form | components: form.components ++ [predicate]})
      end

    if opts[:return_id?] do
      {new_form, predicate_id}
    else
      new_form
    end
  end

  defp do_add_predicate(%__MODULE__{id: id} = form, id, predicate) do
    %{form | components: form.components ++ [predicate]}
  end

  defp do_add_predicate(%__MODULE__{} = form, id, predicate) do
    %{form | components: Enum.map(form.components, &do_add_predicate(&1, id, predicate))}
  end

  defp do_add_predicate(other, _, _), do: other

  defp set_validity(%__MODULE__{components: components} = form) do
    components = Enum.map(components, &set_validity/1)

    if Enum.all?(components, & &1.valid?) do
      %{form | components: components, valid?: true}
    else
      %{form | components: components, valid?: false}
    end
  end

  defp set_validity(%Predicate{errors: []} = predicate), do: %{predicate | valid?: true}
  defp set_validity(%Predicate{errors: _} = predicate), do: %{predicate | valid?: false}

  @doc "Remove the predicate with the given id"
  def remove_predicate(form, id) do
    %{
      form
      | components:
          Enum.flat_map(form.components, fn
            %__MODULE__{} = nested_form ->
              new_nested_form = remove_predicate(nested_form, id)

              remove_if_empty(new_nested_form, form.remove_empty_groups?)

            %Predicate{id: ^id} ->
              []

            predicate ->
              [predicate]
          end)
    }
    |> set_validity()
  end

  @doc "Update the predicate with the given id"
  def update_predicate(form, id, func) do
    %{
      form
      | components:
          Enum.map(form.components, fn
            %__MODULE__{} = nested_form ->
              update_predicate(nested_form, id, func)

            %Predicate{id: ^id} = pred ->
              func.(pred)

            predicate ->
              [predicate]
          end)
    }
    |> set_validity()
  end

  defp predicate_errors(predicate, resource) do
    case Ash.Resource.Info.related(resource, predicate.path) do
      nil ->
        [
          {:operator, "Invalid path #{Enum.join(predicate.path, ".")}", []}
        ]

      resource ->
        errors =
          case Ash.Resource.Info.public_field(resource, predicate.field) do
            nil ->
              [
                {:field, "No such field #{predicate.field}", []}
              ]

            _ ->
              []
          end

        if Ash.Filter.get_function(predicate.operator, resource, true) do
          errors
        else
          if Ash.Filter.get_operator(predicate.operator) do
            errors
          else
            [
              {:operator, "No such operator #{predicate.operator}", []} | errors
            ]
          end
        end
    end
  end

  @add_group_opts [
    to: [
      type: :string,
      doc: "The nested group id to add the group to."
    ],
    operator: [
      type: {:one_of, [:and, :or]},
      default: :and,
      doc: "The operator that the group should have internally."
    ],
    return_id?: [
      type: :boolean,
      default: false,
      doc: "If set to `true`, the function returns `{form, predicate_id}`"
    ]
  ]

  @doc """
  Adde a group to the filter.

  Options:

  #{Spark.OptionsHelpers.docs(@add_group_opts)}
  """
  def add_group(form, opts \\ []) do
    opts = Spark.OptionsHelpers.validate!(opts, @add_group_opts)
    group_id = Ash.UUID.generate()

    group = %__MODULE__{resource: form.resource, operator: opts[:operator], id: group_id}

    new_form =
      if opts[:to] && opts[:to] != form.id do
        set_validity(%{
          form
          | components:
              Enum.map(
                Enum.with_index(form.components),
                &do_add_group(&1, opts[:to], group)
              )
        })
      else
        set_validity(%{form | components: form.components ++ [group]})
      end

    if opts[:return_id?] do
      {new_form, group_id}
    else
      new_form
    end
  end

  defp do_add_group({%AshPhoenix.FilterForm{id: id, name: parent_name} = form, i}, id, group) do
    name = parent_name <> "[components][#{i}]"
    %{form | components: form.components ++ [%{group | name: name}]}
  end

  defp do_add_group({%AshPhoenix.FilterForm{} = form, _i}, id, group) do
    %{
      form
      | components: Enum.map(Enum.with_index(form.components), &do_add_group(&1, id, group))
    }
  end

  defp do_add_group({other, _i}, _, _), do: other

  @doc "Remove the group with the given id"
  def remove_group(form, group_id) do
    %{
      form
      | components:
          Enum.flat_map(form.components, fn
            %__MODULE__{id: ^group_id} ->
              []

            %__MODULE__{} = nested_form ->
              new_nested_form = remove_group(nested_form, group_id)

              remove_if_empty(new_nested_form, form.remove_empty_groups?)

            predicate ->
              [predicate]
          end)
    }
    |> set_validity()
  end

  @doc "Removes the group *or* component with the given id"
  def remove_component(form, group_or_component_id) do
    form
    |> remove_group(group_or_component_id)
    |> remove_component(group_or_component_id)
  end

  defp remove_if_empty(form, false), do: [form]

  defp remove_if_empty(form, true) do
    if Enum.empty?(form.components) do
      []
    else
      [form]
    end
  end

  defimpl Phoenix.HTML.FormData do
    @impl true
    def to_form(form, opts) do
      hidden = [id: form.id]

      %Phoenix.HTML.Form{
        source: form,
        impl: __MODULE__,
        id: opts[:id] || form.id,
        name: opts[:as] || form.name,
        errors: [],
        data: form,
        params: form.params,
        hidden: hidden,
        options: Keyword.put_new(opts, :method, "GET")
      }
    end

    @impl true
    def to_form(form, phoenix_form, :components, _opts) do
      form.components
      |> Enum.with_index()
      |> Enum.map(fn {component, index} ->
        name = Map.get(component, :name, phoenix_form.name)

        Phoenix.HTML.Form.form_for(component, "action",
          transform_errors: form.transform_errors,
          as: name <> "[components][#{index}]"
        )
      end)
    end

    def to_form(_, _, other, _) do
      raise "Invalid inputs_for name #{other}. Only :components is supported"
    end

    @impl true
    def input_type(_, _, _), do: :text_input

    @impl true
    def input_value(%{id: id}, _, :id), do: id
    def input_value(%{negated?: negated?}, _, :negated), do: negated?
    def input_value(%{operator: operator}, _, :operator), do: operator

    def input_value(_, _, field) do
      raise "Invalid filter form field #{field}. Only :id, :negated, and :operator are supported"
    end

    @impl true
    def input_validations(_, _, _), do: []
  end
end
