defmodule AshPhoenix.FilterForm do
  @moduledoc """
  A module to help you create complex forms that generate Ash filters.

  ```elixir
  # Create a FilterForm
  filter_form = AshPhoenix.FilterForm.new(MyApp.Payroll.Employee)
  ```

  FilterForm's comprise 2 concepts, predicates and groups. Predicates are the simple boolean
  expressions you can use to build a query (`name == "Joe"`), and groups can be used to group
  predicates and more groups together. Groups can apply `and` or `or` operators to its nested
  components.

  ```elixir
  # Add a predicate to the root of the form (which is itself a group)
  filter_form = AshPhoenix.add_predicate(filter_form, :some_field, :eq, "Some Value")

  # Add a group and another predicate to that group
  {filter_form, group_id} = AshPhoenix.add_group(filter_form, operator: :or, return_id?: true)
  filter_form = AshPhoenix.add_predicate(filter_form, :another, :eq, "Other", to: group_id)
  ```

  `validate/1` is used to merge the submitted form params into the filter form, and one of the
  provided filter functions to apply the filter as a query, or generate an expression map,
  depending on your requirements:

  ```elixir
  filter_form = AshPhoenix.validate(socket.assigns.filter_form, params)

  # Generate a query and pass it to the Domain
  query = AshPhoenix.FilterForm.filter!(MyApp.Payroll.Employee, filter_form)
  filtered_employees = MyApp.Payroll.read!(query)

  # Or use one of the other filter functions
  AshPhoenix.FilterForm.to_filter_expression(filter_form)
  AshPhoenix.FilterForm.to_filter_map(filter_form)
  ```

  ## LiveView Example

  You can build a form and handle adding and removing nested groups and predicates with the following:

  ```elixir
  alias MyApp.Payroll.Employee

  @impl true
  def render(assigns) do
    ~H\"\"\"
    <.simple_form
      :let={filter_form}
      for={@filter_form}
      phx-change="filter_validate"
      phx-submit="filter_submit"
    >
      <.filter_form_component component={filter_form} />
      <:actions>
        <.button>Submit</.button>
      </:actions>
    </.simple_form>
    <.table id="employees" rows={@employees}>
      <:col :let={employee} label="Payroll ID"><%= employee.employee_id %></:col>
      <:col :let={employee} label="Name"><%= employee.name %></:col>
      <:col :let={employee} label="Position"><%= employee.position %></:col>
    </.table>
    \"\"\"
  end

  attr :component, :map, required: true, doc: "Could be a FilterForm (group) or a Predicate"

  defp filter_form_component(%{component: %{source: %AshPhoenix.FilterForm{}}} = assigns) do
    ~H\"\"\"
    <div class="border-gray-50 border-8 p-4 rounded-xl mt-4">
      <div class="flex flex-row justify-between">
        <div class="flex flex-row gap-2 items-center">Filter</div>
        <div class="flex flex-row gap-2 items-center">
          <.input type="select" field={@component[:operator]} options={["and", "or"]} />
          <.button phx-click="add_filter_group" phx-value-component-id={@component.source.id} type="button">
            Add Group
          </.button>
          <.button
            phx-click="add_filter_predicate"
            phx-value-component-id={@component.source.id}
            type="button"
          >
            Add Predicate
          </.button>
          <.button
            phx-click="remove_filter_component"
            phx-value-component-id={@component.source.id}
            type="button"
          >
            Remove Group
          </.button>
        </div>
      </div>
      <.inputs_for :let={component} field={@component[:components]}>
        <.filter_form_component component={component} />
      </.inputs_for>
    </div>
    \"\"\"
  end

  defp filter_form_component(
         %{component: %{source: %AshPhoenix.FilterForm.Predicate{}}} = assigns
       ) do
    ~H\"\"\"
    <div class="flex flex-row gap-2 mt-4">
      <.input
        type="select"
        options={AshPhoenix.FilterForm.fields(Employee)}
        field={@component[:field]}
      />
      <.input
        type="select"
        options={AshPhoenix.FilterForm.predicates(Employee)}
        field={@component[:operator]}
      />
      <.input field={@component[:value]} />
      <.button
        phx-click="remove_filter_component"
        phx-value-component-id={@component.source.id}
        type="button"
      >
        Remove
      </.button>
    </div>
    \"\"\"
  end

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:filter_form, AshPhoenix.FilterForm.new(Employee))
      |> assign(:employees, Employee.read_all!())

    {:ok, socket}
  end

  @impl true
  def handle_event("filter_validate", %{"filter" => params}, socket) do
    {:noreply,
     assign(socket,
       filter_form: AshPhoenix.FilterForm.validate(socket.assigns.filter_form, params)
     )}
  end

  def handle_event("filter_submit", %{"filter" => params}, socket) do
    filter_form = AshPhoenix.FilterForm.validate(socket.assigns.filter_form, params)

    case AshPhoenix.FilterForm.filter(Employee, filter_form) do
      {:ok, query} ->
        {:noreply,
         socket
         |> assign(:employees, Employee.read_all!(query: query))
         |> assign(:filter_form, filter_form)}

      {:error, filter_form} ->
        {:noreply, assign(socket, filter_form: filter_form)}
    end
  end

  def handle_event("remove_filter_component", %{"component-id" => component_id}, socket) do
    {:noreply,
     assign(socket,
       filter_form:
         AshPhoenix.FilterForm.remove_component(socket.assigns.filter_form, component_id)
     )}
  end

  def handle_event("add_filter_group", %{"component-id" => component_id}, socket) do
    {:noreply,
     assign(socket,
       filter_form: AshPhoenix.FilterForm.add_group(socket.assigns.filter_form, to: component_id)
     )}
  end

  def handle_event("add_filter_predicate", %{"component-id" => component_id}, socket) do
    {:noreply,
     assign(socket,
       filter_form:
         AshPhoenix.FilterForm.add_predicate(socket.assigns.filter_form, :name, :contains, nil,
           to: component_id
         )
     )}
  end
  ```
  """

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
  require Ash.Expr

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
    warn_on_unhandled_errors?: [
      type: :boolean,
      default: true,
      doc: "Whether or not to emit warning log on unhandled form errors"
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

  @doc """
  Create a new filter form.

  Options:
  #{Spark.Options.docs(@new_opts)}
  """
  def new(resource, opts \\ []) do
    opts = Spark.Options.validate!(opts, @new_opts)
    params = opts[:params]

    params = sanitize_params(params)

    params =
      if predicate?(params) do
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

  Passing `reset_on_change?: false` into `opts` will prevent predicates to reset
  the `value` and `operator` fields to `nil` if the predicate `field` changes.
  """
  def validate(form, params \\ %{}, opts \\ []) do
    params = sanitize_params(params)

    params =
      if predicate?(params) do
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
        components: validate_components(form, params["components"], opts),
        operator: to_existing_atom(params["operator"] || :and),
        negated?: params["negated"] || false
    }
    |> set_validity()
  end

  @doc """
  Returns a filter map that can be provided to `Ash.Filter.parse`

  This allows for things like saving a stored filter. Does not currently support parameterizing calculations or functions.
  """
  def to_filter_map(form) do
    if form.valid? do
      case do_to_filter_map(form, form.resource) do
        {:ok, expr} ->
          {:ok, expr}

        {:error, %__MODULE__{} = form} ->
          {:error, form}
      end
    else
      {:error, form}
    end
  end

  defp do_to_filter_map(%__MODULE__{components: []}, _), do: {:ok, true}

  defp do_to_filter_map(
         %__MODULE__{components: components, operator: operator, negated?: negated?} = form,
         resource
       ) do
    {filters, components, errors?} =
      Enum.reduce(components, {[], [], false}, fn component, {filters, components, errors?} ->
        case do_to_filter_map(component, resource) do
          {:ok, component_filter} ->
            {filters ++ [component_filter], components ++ [component], errors?}

          {:error, component} ->
            {filters, components ++ [component], true}
        end
      end)

    if errors? do
      {:error, %{form | components: components}}
    else
      expr = %{to_string(operator) => filters}

      if negated? do
        {:ok, %{"not" => expr}}
      else
        {:ok, expr}
      end
    end
  end

  defp do_to_filter_map(
         %Predicate{
           field: field,
           value: value,
           operator: operator,
           negated?: negated?,
           arguments: arguments,
           path: path
         },
         _resource
       ) do
    expr =
      if arguments && arguments.input not in [nil, %{}] do
        put_at_path(%{}, Enum.map(path, &to_string/1), %{
          to_string(field) => %{to_string(operator) => value, "input" => arguments.input}
        })
      else
        put_at_path(%{}, Enum.map(path, &to_string/1), %{
          to_string(field) => %{to_string(operator) => value}
        })
      end

    if negated? do
      {:ok, %{"not" => expr}}
    else
      {:ok, expr}
    end
  end

  defp put_at_path(_, [], value), do: value

  defp put_at_path(map, [key], value) do
    Map.put(map || %{}, key, value)
  end

  defp put_at_path(map, [key | rest], value) do
    map
    |> Kernel.||(%{})
    |> Map.put_new(key, %{})
    |> Map.update!(key, &put_at_path(&1, rest, value))
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

        {:error, %__MODULE__{} = form} ->
          {:error, form}

        {:error, error} ->
          {:error, %{form | errors: List.wrap(error)}}
      end
    else
      {:error, form}
    end
  end

  @doc """
  Same as `to_filter_expression/1` but raises on errors.
  """
  def to_filter_expression!(form) do
    case to_filter_expression(form) do
      {:ok, filter} ->
        filter

      {:error, %__MODULE__{} = form} ->
        error =
          form
          |> raw_errors()
          |> Ash.Error.to_error_class()

        raise error

      {:error, error} ->
        raise Ash.Error.to_error_class(error)
    end
  end

  @deprecated "Use to_filter_expression!/1 instead"
  def to_filter!(form), do: to_filter_expression!(form)

  @doc """
  Returns a flat list of all errors on all predicates in the filter, made safe for display in a form.

  Only errors that implement the `AshPhoenix.FormData.Error` protocol are displayed.
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

  @doc """
  Returns a flat list of all errors on all predicates in the filter, without transforming.
  """
  def raw_errors(%__MODULE__{components: components}) do
    Enum.flat_map(
      components,
      &raw_errors(&1)
    )
  end

  def raw_errors(%Predicate{} = predicate) do
    predicate.errors
  end

  defp do_to_filter_expression(%__MODULE__{components: []}, _), do: {:ok, %{}}

  defp do_to_filter_expression(
         %__MODULE__{components: components, operator: operator, negated?: negated?} = form,
         resource
       ) do
    {filters, components, errors?} =
      Enum.reduce(components, {[], [], false}, fn component, {filters, components, errors?} ->
        case do_to_filter_expression(component, resource) do
          {:ok, component_filter} ->
            {filters ++ [component_filter], components ++ [component], errors?}

          {:error, errors} ->
            {filters,
             components ++
               [
                 %{
                   component
                   | valid?: false,
                     errors: List.wrap(component.errors) ++ List.wrap(errors)
                 }
               ], true}
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
           arguments: arguments,
           operator: operator,
           negated?: negated?,
           path: path
         } = predicate,
         resource
       ) do
    ref =
      case Ash.Resource.Info.public_calculation(
             Ash.Resource.Info.related(resource, path),
             field
           ) do
        nil ->
          {:ok, Ash.Expr.expr(^Ash.Expr.ref(List.wrap(path), field))}

        %{calculation: {module, calc_opts}} = calc ->
          with {:ok, input} <-
                 Ash.Query.validate_calculation_arguments(
                   calc,
                   arguments.input || %{}
                 ),
               {:ok, calc} <-
                 Ash.Query.Calculation.new(
                   calc.name,
                   module,
                   calc_opts,
                   calc.type,
                   calc.constraints,
                   arguments: input,
                   async?: calc.async?,
                   filterable?: calc.filterable?,
                   sortable?: calc.sortable?,
                   sensitive?: calc.sensitive?,
                   load: calc.load,
                   calc_name: calc.name,
                   source_context: %{}
                 ) do
            {:ok,
             %Ash.Query.Ref{
               attribute: calc,
               relationship_path: path,
               resource: Ash.Resource.Info.related(resource, path),
               input?: true
             }}
          end
      end

    case ref do
      {:ok, ref} ->
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

      {:error, error} ->
        {:error, error}
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
    Ash.Query.do_filter(query, to_filter_expression!(form))
  end

  defp sanitize_params(params) do
    if predicate?(params) do
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
        "arguments" => params[:arguments] || params["arguments"],
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
    if predicate?(params) do
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

    arguments =
      with related when not is_nil(related) <- Ash.Resource.Info.related(form.resource, path),
           calc when not is_nil(calc) <- Ash.Resource.Info.calculation(related, field) do
        calc.arguments
      else
        _ ->
          []
      end

    predicate = %AshPhoenix.FilterForm.Predicate{
      id: params["id"],
      field: field,
      value: params["value"],
      path: path,
      transform_errors: form.transform_errors,
      arguments: AshPhoenix.FilterForm.Arguments.new(params["arguments"] || %{}, arguments),
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
      nil ->
        {path, field}

      related ->
        %{name: new_field} = List.first(Ash.Resource.Info.public_attributes(related))
        {extended_path, new_field}
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

  defp validate_components(form, component_params, opts) do
    form_without_components = %{form | components: []}

    component_params
    |> Enum.sort_by(fn {key, _} ->
      String.to_integer(key)
    end)
    |> Enum.map(&validate_component(form_without_components, &1, form.components, opts))
  end

  defp validate_component(form, {key, params}, current_components, opts) do
    reset_on_change? = Keyword.get(opts, :reset_on_change?, true)

    id = params[:id] || params["id"]

    match_component =
      id && Enum.find(current_components, fn %{id: component_id} -> component_id == id end)

    if match_component do
      case match_component do
        %__MODULE__{} ->
          validate(match_component, params)

        %Predicate{field: field} ->
          new_predicate = new_predicate(params, form)

          if reset_on_change? && new_predicate.field != field && not is_nil(new_predicate.value) do
            %{
              new_predicate
              | value: nil,
                operator: nil,
                params: Map.merge(new_predicate.params, %{"value" => nil, "operator" => nil})
            }
          else
            new_predicate
          end
      end
    else
      if predicate?(params) do
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

  defp predicate?(params) do
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
  def params_for_query(%AshPhoenix.FilterForm.Predicate{} = predicate) do
    params =
      Map.new(~w(field value operator negated? path)a, fn field ->
        if field == :path do
          {to_string(field), Enum.join(predicate.path, ".")}
        else
          {to_string(field), Map.get(predicate, field)}
        end
      end)

    case predicate.arguments do
      %AshPhoenix.FilterForm.Arguments{} = arguments ->
        argument_params = params_for_query(arguments)

        if Enum.empty?(argument_params) do
          params
        else
          Map.put(params, "arguments", argument_params)
        end

      _ ->
        params
    end
  end

  def params_for_query(%__MODULE__{} = form) do
    params = %{
      "negated" => form.negated?,
      "operator" => to_string(form.operator)
    }

    if is_nil(form.components) || Enum.empty?(form.components) do
      params
    else
      Map.put(
        params,
        "components",
        form.components
        |> Enum.with_index()
        |> Map.new(fn {value, index} ->
          {to_string(index), params_for_query(value)}
        end)
      )
    end
  end

  def params_for_query(%AshPhoenix.FilterForm.Arguments{} = arguments) do
    Map.new(arguments.arguments, fn argument ->
      {to_string(argument.name),
       Map.get(
         arguments.input,
         argument.name,
         Map.get(
           arguments.params,
           argument.name,
           Map.get(arguments.params, to_string(argument.name))
         )
       )}
    end)
  end

  @doc "Returns the list of available predicates for the given resource, which may be functions or operators."
  def predicates(resource) do
    resource
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

  #{Spark.Options.docs(@add_predicate_opts)}
  """
  def add_predicate(form, field, operator_or_function, value, opts \\ []) do
    opts = Spark.Options.validate!(opts, @add_predicate_opts)

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
              predicate
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
  Add a group to the filter. A group can contain predicates and other groups,
  allowing you to build quite complex nested filters.

  Options:

  #{Spark.Options.docs(@add_group_opts)}
  """
  def add_group(form, opts \\ []) do
    opts = Spark.Options.validate!(opts, @add_group_opts)
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

  @doc "Removes the group *or* predicate with the given id"
  def remove_component(form, group_or_predicate_id) do
    form
    |> remove_group(group_or_predicate_id)
    |> remove_predicate(group_or_predicate_id)
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
        errors: opts[:errors] || [],
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

        case component do
          %AshPhoenix.FilterForm{} ->
            to_form(component,
              as: name <> "[components][#{index}]",
              id: component.id,
              errors: AshPhoenix.FilterForm.errors(component)
            )

          %AshPhoenix.FilterForm.Predicate{} ->
            Phoenix.HTML.FormData.AshPhoenix.FilterForm.Predicate.to_form(component,
              as: name <> "[components][#{index}]",
              id: component.id,
              errors: AshPhoenix.FilterForm.errors(component)
            )
        end
      end)
    end

    def to_form(_, _, other, _) do
      raise "Invalid inputs_for name #{other}. Only :components is supported"
    end

    @impl true
    def input_value(%{id: id}, _, :id), do: id
    def input_value(%{negated?: negated?}, _, :negated), do: negated?
    def input_value(%{operator: operator}, _, :operator), do: operator

    def input_value(form, phoenix_form, :components) do
      to_form(form, phoenix_form, :components, [])
    end

    def input_value(_, _, _field) do
      nil
    end

    @impl true
    def input_validations(_, _, _), do: []
  end
end
