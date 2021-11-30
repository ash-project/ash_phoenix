defmodule AshPhoenix.FilterForm do
  defstruct [:id, :resource, params: %{}, components: [], operator: :and]

  alias AshPhoenix.FilterForm.Predicate

  @moduledoc """
  Create a new filter form
  """
  def new(resource, params \\ %{}) do
    params =
      if is_operator?(params) do
        %{
          operator: :and,
          components: %{"0" => params}
        }
      else
        params
      end

    params =
      params
      |> params_to_list()
      |> add_ids()

    %__MODULE__{
      id: params["id"] || params[:id],
      resource: resource,
      params: params,
      components: parse_components(resource, params["components"] || params[:components]),
      operator: to_existing_atom(params["operator"] || params[:operator] || :and)
    }
  end

  def validate(form, params \\ %{}) do
    params =
      if is_operator?(params) do
        %{
          operator: :and,
          components: %{"0" => params}
        }
      else
        params
      end

    params =
      params
      |> params_to_list()
      |> add_ids()

    %{
      form
      | params: params_to_list(params),
        components:
          validate_components(form.components, params["components"] || params[:components]),
        operator: to_existing_atom(params["operator"] || params[:operator] || :and)
    }
  end

  defp add_ids(params) do
    params =
      if params[:id] || params["id"] do
        params
      else
        Map.put(params, :id, Ash.UUID.generate())
      end

    field =
      if Map.has_key?(params, :components) do
        :components
      else
        if Map.has_key?(params, "components") do
          "components"
        end
      end

    if field do
      Map.update!(params, field, fn components ->
        Enum.map(components, fn component ->
          if component[:id] || component["id"] do
            component
          else
            Map.put(component, :id, Ash.UUID.generate())
          end
        end)
      end)
    else
      params
    end
  end

  defp params_to_list(params) do
    field =
      if Map.has_key?(params, :components) do
        :components
      else
        if Map.has_key?(params, "components") do
          "components"
        end
      end

    if field do
      Map.update!(params, field, fn components ->
        if is_list(components) do
          components
        else
          components
          |> Enum.sort_by(&elem(&1, 0))
          |> Enum.map(&elem(&1, 1))
          |> Enum.map(&params_to_list/1)
        end
      end)
    else
      params
    end
  end

  defp parse_components(resource, component_params) do
    component_params
    |> Kernel.||([])
    |> Enum.map(&parse_component(resource, &1))
  end

  defp parse_component(resource, params) do
    if is_operator?(params) do
      # Eventually, components may have references w/ paths
      # also, we should validate references here
      new_predicate(params)
    else
      new(resource, params)
    end
  end

  defp new_predicate(params) do
    %AshPhoenix.FilterForm.Predicate{
      id: params[:id] || params["id"] || Ash.UUID.generate(),
      field: to_existing_atom(params["field"] || params[:field]),
      value: params["value"] || params[:value],
      operator: to_existing_atom(params["operator"] || params[:operator] || :eq)
    }
  end

  defp validate_components(form, component_params) do
    component_params
    |> Kernel.||([])
    |> Enum.map(&validate_component(form, &1))
  end

  defp validate_component(form, params) do
    id = params[:id] || params["id"]

    match_component =
      id && Enum.find(form.components, fn %{id: component_id} -> component_id == id end)

    if match_component do
      %{
        form
        | components:
            Enum.map(form.components, fn component ->
              if match_component.id == component.id do
                case component do
                  %__MODULE__{} ->
                    new(form.resource, params)

                  %Predicate{} ->
                    new_predicate(params)
                end
              else
                component
              end
            end)
      }
    else
      component =
        if is_operator?(params) do
          new_predicate(params)
        else
          new(form.resource, params)
        end

      %{form | components: form.components ++ [component]}
    end
  end

  defp is_operator?(params) do
    params["field"] || params[:field] || params[:value] || params["value"]
  end

  defp to_existing_atom(value) when is_atom(value), do: value
  defp to_existing_atom(value), do: String.to_existing_atom(value)

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

  @doc "Returns the list of available fields, which may be attribuets, calculations, or aggregates."
  def fields(form) do
    form.resource
    |> Ash.Resource.Info.public_aggregates()
    |> Enum.concat(Ash.Resource.Info.public_calculations(form.resource))
    |> Enum.concat(Ash.Resource.Info.public_attributes(form.resource))
    |> Enum.map(& &1.name)
  end

  @add_predicate_opts [
    to: [
      type: :string,
      doc:
        "The group id to add the predicate to. If not set, will be added to the top level group."
    ]
  ]

  def add_predicate(form, field, operator_or_function, value, opts \\ []) do
    opts = Ash.OptionsHelpers.validate!(opts, @add_predicate_opts)

    predicate = %Predicate{
      id: Ash.UUID.generate(),
      field: field,
      value: value,
      operator: operator_or_function
    }

    if opts[:to] && opts[:to] != form.id do
      %{form | components: Enum.map(form.components, &do_add_predicate(&1, opts[:to], predicate))}
    else
      %{form | components: form.components ++ [predicate]}
    end
  end

  defp do_add_predicate(%__MODULE__{id: id} = form, id, predicate) do
    %{form | components: form.components ++ [predicate]}
  end

  defp do_add_predicate(%__MODULE__{} = form, id, predicate) do
    %{form | components: Enum.map(form.components, &do_add_predicate(&1, id, predicate))}
  end

  defp do_add_predicate(other, _, _), do: other

  @add_group_opts [
    to: [
      type: :string,
      doc: "The nested group id to add the group to."
    ],
    operator: [
      type: {:one_of, [:and, :or]},
      default: :and,
      doc: "The operator that the group should have internally."
    ]
  ]

  @doc """
  Adde a group to the filter.

  Options:

  #{Ash.OptionsHelpers.docs(@add_group_opts)}
  """
  def add_group(form, opts \\ []) do
    opts = Ash.OptionsHelpers.validate!(opts, @add_group_opts)

    group = %__MODULE__{operator: opts[:operator], id: Ash.UUID.generate()}

    if opts[:to] && opts[:to] != form.id do
      %{form | components: Enum.map(form.components, &do_add_group(&1, opts[:to], group))}
    else
      %{form | components: form.components ++ [group]}
    end
  end

  defp do_add_group(%AshPhoenix.FilterForm{id: id} = form, id, group) do
    %{form | components: form.components ++ [group]}
  end

  defp do_add_group(%AshPhoenix.FilterForm{} = form, id, group) do
    %{form | components: Enum.map(form.components, &do_add_group(&1, id, group))}
  end

  defp do_add_group(other, _, _), do: other

  defimpl Phoenix.HTML.FormData do
    @impl true
    def to_form(form, opts) do
      hidden = [id: form.id]

      %Phoenix.HTML.Form{
        source: form,
        impl: __MODULE__,
        id: form.id,
        name: form.id,
        errors: [],
        data: form,
        params: form.params,
        hidden: hidden,
        options: Keyword.put_new(opts, :method, "GET")
      }
    end

    # @impl true
    # def to_form(form, _phoenix_form, field, opts) do
    #   unless Keyword.has_key?(form.form_keys, field) do
    #     raise AshPhoenix.Form.NoFormConfigured,
    #       field: field,
    #       available: Keyword.keys(form.form_keys || [])
    #   end

    #   case form.form_keys[field][:type] || :single do
    #     :single ->
    #       if form.forms[field] do
    #         to_form(form.forms[field], opts)
    #       end

    #     :list ->
    #       form.forms[field]
    #       |> Kernel.||([])
    #       |> Enum.map(&to_form(&1, opts))
    #   end
    #   |> List.wrap()
    # end
  end
end
