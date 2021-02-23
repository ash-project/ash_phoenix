defimpl Phoenix.HTML.FormData, for: Ash.Changeset do
  # Most of this logic was simply copied from ecto
  # The goal here is to eventually lift complex validations
  # up into the form.

  @impl true
  def input_type(%{resource: resource, action: action}, _, field) do
    attribute = Ash.Resource.Info.attribute(resource, field)

    if attribute do
      type_to_form_type(attribute.type)
    else
      argument = get_argument(action, field)

      if argument do
        type_to_form_type(argument.type)
      else
        :text_input
      end
    end
  end

  defp get_argument(action, field) when is_atom(field) do
    Enum.find(action.arguments, &(&1.name == field))
  end

  defp get_argument(action, field) when is_binary(field) do
    Enum.find(action.arguments, &(to_string(&1.name) == field))
  end

  defp type_to_form_type(type) do
    case Ash.Type.ecto_type(type) do
      :integer -> :number_input
      :boolean -> :checkbox
      :date -> :date_select
      :time -> :time_select
      :utc_datetime -> :datetime_select
      :naive_datetime -> :datetime_select
      _ -> :text_input
    end
  end

  @impl true
  def input_value(changeset, form, field) do
    case Keyword.fetch(form.options, :value) do
      {:ok, value} ->
        value || ""

      _ ->
        case get_changing_value(changeset, field) do
          {:ok, value} ->
            value

          :error ->
            case Map.fetch(changeset.data, field) do
              {:ok, value} ->
                value

              _ ->
                Ash.Changeset.get_argument(changeset, field)
            end
        end
    end
  end

  defp get_changing_value(changeset, field) do
    with :error <- Map.fetch(changeset.attributes, field),
         :error <- Map.fetch(changeset.params, field) do
      Map.fetch(changeset.params, to_string(field))
    end
  end

  @impl true
  def to_form(changeset, opts) do
    {name, opts} = Keyword.pop(opts, :as)

    name = to_string(name || form_for_name(changeset.resource))
    id = Keyword.get(opts, :id) || name

    hidden =
      if changeset.action_type == :update do
        changeset.data
        |> Map.take(Ash.Resource.Info.primary_key(changeset.resource))
        |> Enum.to_list()
      else
        []
      end

    %Phoenix.HTML.Form{
      action: changeset.action.name,
      source: Ash.Changeset.put_context(changeset, :form, %{path: []}),
      impl: __MODULE__,
      id: id,
      name: name,
      errors: form_for_errors(changeset, opts),
      data: changeset.data,
      params: changeset.params,
      hidden: hidden,
      options: Keyword.put_new(opts, :method, form_for_method(changeset))
    }
  end

  @impl true
  def to_form(changeset, form, field, opts) do
    {name, opts} = Keyword.pop(opts, :as)
    {id, opts} = Keyword.pop(opts, :id)
    {prepend, opts} = Keyword.pop(opts, :prepend, [])
    {append, opts} = Keyword.pop(opts, :append, [])
    changeset_opts = [skip_defaults: :all]
    id = to_string(id || form.id <> "_#{field}")
    name = to_string(name || form.name <> "[#{field}]")

    {source, resource, data, opts} =
      cond do
        attr = Ash.Resource.Info.attribute(changeset.resource, field) ->
          case get_embedded(attr.type) do
            nil ->
              raise "Cannot use `form_for` with an attribute unless the type is an embedded resource"

            resource ->
              data = Ash.Changeset.get_attribute(changeset, attr.name)

              data =
                case attr.type do
                  {:array, _} ->
                    List.wrap(data)

                  _ ->
                    data
                end

              {{:attr, attr}, resource, data, opts}
          end

        arg =
            Enum.find(
              changeset.action.arguments,
              &(&1.name == field || to_string(&1.name) == field)
            ) ->
          case get_embedded(arg.type) do
            nil ->
              case get_managed_relationship(changeset.resource, changeset.action, arg.name) do
                nil ->
                  raise "Cannot use `form_for` with an argument unless the type is an embedded resource, or unless there is a `manage_relationship` change that references the argument"

                {relationship, manage_opts} ->
                  data = Map.get(changeset.relationships, relationship.name)

                  data =
                    case relationship.cardinality do
                      :many ->
                        List.wrap(data)

                      _ when is_list(data) ->
                        Enum.at(data, 0)

                      _ ->
                        data
                    end

                  {{:manage_relationship, relationship}, relationship.destination, data,
                   Keyword.merge(manage_opts, opts)}
              end

            resource ->
              data = Ash.Changeset.get_argument(changeset, arg.name)

              data =
                case arg.type do
                  {:array, _} ->
                    List.wrap(data)

                  _ ->
                    data
                end

              {{:embed_arg, arg}, resource, data}
          end

        relationship = Ash.Resource.Info.relationship(changeset.resource, field) ->
          data = relationship_data(changeset, relationship, changeset_opts)

          data =
            case relationship.cardinality do
              :many ->
                List.wrap(data)

              _ when is_list(data) ->
                Enum.at(data, 0)

              _ ->
                data
            end

          {{:manage_relationship, relationship}, relationship.destination, data, opts}
      end

    data =
      if is_list(data) do
        prepend ++ data ++ append
      else
        data
      end

    changeset
    |> to_nested_form(data, source, resource, id, name, opts, changeset_opts)
    |> List.wrap()
  end

  defp relationship_data(changeset, relationship, changeset_opts) do
    value =
      case Map.get(changeset.data, relationship.name) do
        %Ash.NotLoaded{} ->
          []

        value ->
          value
      end

    case relationship.type do
      :many_to_many ->
        join_relationship =
          Ash.Resource.Info.relationship(relationship.destination, relationship.destination)

        value
        |> List.wrap()
        |> Enum.map(&Ash.Changeset.new/1)
        |> Enum.map(&Ash.Changeset.set_context(&1, relationship.context))
        |> Enum.map(fn value_changeset ->
          case Map.get(changeset.data, join_relationship.name) do
            %Ash.NotLoaded{} ->
              value_changeset

            value ->
              value
              |> Enum.find(fn join_row ->
                Map.get(join_row, relationship.source_field_on_join_table) ==
                  Map.get(changeset.data, relationship.source_field) &&
                  Map.get(join_row, relationship) ==
                    Map.get(changeset.data, relationship.destination_field)
              end)
              |> case do
                nil ->
                  value_changeset

                join_row ->
                  join_changeset =
                    join_row
                    |> Ash.Changeset.new()
                    |> Ash.Changeset.set_context(join_relationship.context)

                  Ash.Changeset.put_context(changeset, :private, %{
                    join_changeset: join_changeset
                  })
              end
          end
        end)
        |> apply_relationship_instructions(changeset, relationship, changeset_opts)

      _ ->
        value
        |> List.wrap()
        |> Enum.map(&Ash.Changeset.new/1)
        |> apply_relationship_instructions(changeset, relationship, changeset_opts)
    end
  end

  defp apply_relationship_instructions(value, changeset, relationship, changeset_opts) do
    changeset.relationships
    |> Map.get(relationship.name)
    |> List.wrap()
    |> Enum.reduce(value, fn {changes, opts}, value ->
      apply_relationship_change(value, changes, relationship, opts, changeset_opts)
    end)
  end

  defp apply_relationship_change(value, manage_value, relationship, opts, changeset_opts) do
    pkeys = pkeys(relationship)

    {relationship_value, unused_inputs} =
      Enum.reduce(value, {[], manage_value}, fn changeset, {acc, manage_value} ->
        case find_match(manage_value, changeset, pkeys) do
          nil ->
            case opts[:on_missing] do
              instruction when instruction in [:error, :ignore] ->
                {[changeset | acc], manage_value}

              _ ->
                {acc, manage_value}
            end

          match ->
            case opts[:on_match] do
              instruction when instruction in [:error, :ignore] ->
                {[changeset | acc], manage_value -- [match]}

              instruction when instruction in [:destroy, :unrelate] ->
                {acc, manage_value -- match}

              :create ->
                {acc, manage_value}

              {:unrelate, _} ->
                {acc, manage_value}

              :update ->
                action_name = Ash.Resource.Info.primary_action!(changeset.resource, :update).name

                {[Ash.Changeset.for_update(changeset, action_name, match, changeset_opts) | acc],
                 [match | manage_value]}

              {:update, action_name} ->
                {[Ash.Changeset.for_update(changeset, action_name, match, changeset_opts) | acc],
                 [match | manage_value]}

              {:update, action_name, join_table_action_name, params} ->
                join_row =
                  case changeset.context[:private][:join_row] do
                    nil ->
                      raise "The join relationship must be loaded if using `inputs_for` with a managed relationship that specifies a join action/params"

                    join_row ->
                      Ash.Changeset.for_update(
                        join_row,
                        join_table_action_name,
                        Map.take(match, params ++ Enum.map(params, &to_string/1)),
                        changeset_opts
                      )
                  end

                changeset =
                  changeset
                  |> Ash.Changeset.for_update(action_name, match, changeset_opts)
                  |> Ash.Changeset.put_context(:private, %{join_row: join_row})

                {[changeset | acc], manage_value -- [match]}
            end
        end
      end)

    new_changesets =
      if opts[:on_no_match] in [:ignore, :error] do
        []
      else
        for input <- unused_inputs do
          case opts[:on_no_match] do
            :create ->
              action = Ash.Resource.Info.primary_action!(relationship.destination, :create)

              Ash.Changeset.for_create(
                relationship.destination,
                action.name,
                input,
                changeset_opts
              )

            {:create, action_name} ->
              Ash.Changeset.for_create(
                relationship.destination,
                action_name,
                input,
                changeset_opts
              )

            {:create, action_name, join_table_action_name, params} ->
              join_row =
                Ash.Changeset.for_create(
                  relationship.through,
                  join_table_action_name,
                  Map.take(input, params ++ Enum.map(params, &to_string/1)),
                  changeset_opts
                )

              relationship.destination
              |> Ash.Changeset.for_create(action_name, input, changeset_opts)
              |> Ash.Changeset.put_context(:private, %{join_row: join_row})
          end
        end
      end

    Enum.reverse(relationship_value, new_changesets)
  end

  defp get_managed_relationship(resource, action, arg_name) do
    action.changes
    |> Enum.find(fn
      %{change: {Ash.Resource.Change.ManageRelationship, opts}} ->
        opts[:argument] == arg_name

      _ ->
        false
    end)
    |> case do
      nil ->
        nil

      %{change: {_, opts}} ->
        {Ash.Resource.Info.relationship(resource, opts[:relationship_name]), opts[:opts]}
    end
  end

  defp pkeys(relationship) do
    identities =
      relationship.destination
      |> Ash.Resource.Info.identities()
      |> Enum.map(& &1.keys)

    [Ash.Resource.Info.primary_key(relationship.destination) | identities]
  end

  defp find_match(current_value, input, pkeys) do
    Enum.find(current_value, fn
      %Ash.NotLoaded{} ->
        false

      loaded ->
        Enum.any?(pkeys, fn pkey ->
          matches?(loaded, input, pkey)
        end)
    end)
  end

  defp matches?(current_value, input, pkey) do
    Enum.all?(pkey, fn field ->
      with {:ok, left} <- fetch_field(current_value, field),
           {:ok, right} <- fetch_field(input, field) do
        left == right
      else
        _ ->
          false
      end
    end)
  end

  defp fetch_field(input, field) do
    case Map.fetch(input, field) do
      {:ok, value} ->
        {:ok, value}

      :error ->
        Map.fetch(input, to_string(field))
    end
  end

  defp to_nested_form(
         original_changeset,
         changesets,
         {:manage_relationship, %{cardinality: :many} = rel},
         _resource,
         id,
         name,
         opts,
         _changeset_opts
       ) do
    changesets
    |> Enum.map(&customize_changeset(&1, original_changeset, :relationship, rel))
    |> Enum.with_index()
    |> Enum.map(fn {changeset, index} ->
      index_string = Integer.to_string(index)

      hidden =
        if changeset.action_type == :update do
          changeset.data
          |> Map.take(Ash.Resource.Info.primary_key(changeset.resource))
          |> Enum.to_list()
        else
          []
        end

      %Phoenix.HTML.Form{
        action: changeset.action.name,
        source: changeset,
        impl: __MODULE__,
        id: id <> "_" <> index_string,
        name: name <> "[" <> index_string <> "]",
        index: index,
        errors: form_for_errors(changeset, opts),
        data: changeset.data,
        params: changeset.params,
        hidden: hidden,
        options: opts |> IO.inspect()
      }
    end)
  end

  defp to_nested_form(
         original_changeset,
         changeset,
         {:manage_relationship, %{cardinality: :one} = rel},
         _resource,
         id,
         name,
         opts,
         _changeset_opts
       ) do
    if changeset do
      changeset = customize_changeset(changeset, original_changeset, :relationship, rel)

      hidden =
        if changeset.action_type == :update do
          changeset.data
          |> Map.take(Ash.Resource.Info.primary_key(changeset.resource))
          |> Enum.to_list()
        else
          []
        end

      %Phoenix.HTML.Form{
        action: changeset.action && changeset.action.name,
        source: changeset,
        impl: __MODULE__,
        id: id,
        name: name,
        errors: form_for_errors(changeset, opts),
        data: changeset.data,
        params: changeset.params,
        hidden: hidden,
        options: opts
      }
    else
      []
    end
  end

  defp to_nested_form(
         original_changeset,
         data,
         {type, attribute},
         resource,
         id,
         name,
         opts,
         changeset_opts
       )
       when is_list(data) and type in [:attr, :embed_arg] do
    create_action =
      attribute.constraints[:create_action] ||
        Ash.Resource.Info.primary_action!(resource, :create).name

    update_action =
      attribute.constraints[:update_action] ||
        Ash.Resource.Info.primary_action!(resource, :update).name

    changesets =
      data
      |> Enum.map(fn data ->
        if is_struct(data) do
          Ash.Changeset.for_update(data, update_action, %{}, changeset_opts)
        else
          Ash.Changeset.for_create(resource, create_action, data, changeset_opts)
        end
      end)
      |> Enum.map(&customize_changeset(&1, original_changeset, :embed, attribute))

    for {changeset, index} <- Enum.with_index(changesets) do
      index_string = Integer.to_string(index)

      hidden =
        if changeset.action_type == :update do
          changeset.data
          |> Map.take(Ash.Resource.Info.primary_key(changeset.resource))
          |> Enum.to_list()
        else
          []
        end

      %Phoenix.HTML.Form{
        action: changeset.action.name,
        source:
          Ash.Changeset.put_context(changeset, :form, %{
            path: (original_changeset.context[:form][:path] || []) ++ [attribute.name]
          }),
        impl: __MODULE__,
        id: id <> "_" <> index_string,
        name: name <> "[" <> index_string <> "]",
        index: index,
        errors: form_for_errors(changeset, opts),
        data: data,
        params: changeset.params,
        hidden: hidden,
        options: opts
      }
    end
  end

  defp to_nested_form(
         original_changeset,
         data,
         {type, attribute},
         resource,
         id,
         name,
         opts,
         changeset_opts
       )
       when type in [:attr, :embed_arg] do
    create_action =
      attribute.constraints[:create_action] ||
        Ash.Resource.Info.primary_action!(resource, :create).name

    update_action =
      attribute.constraints[:update_action] ||
        Ash.Resource.Info.primary_action!(resource, :update).name

    changeset =
      cond do
        is_struct(data) ->
          Ash.Changeset.for_update(data, update_action, %{}, changeset_opts)

        is_nil(data) ->
          nil

        true ->
          Ash.Changeset.for_create(resource, create_action, data, changeset_opts)
      end

    changeset = customize_changeset(changeset, original_changeset, :embed, attribute)

    if changeset do
      hidden =
        if changeset.action_type == :update do
          changeset.data
          |> Map.take(Ash.Resource.Info.primary_key(changeset.resource))
          |> Enum.to_list()
        else
          []
        end

      %Phoenix.HTML.Form{
        source: changeset,
        impl: __MODULE__,
        id: id,
        name: name,
        errors: form_for_errors(changeset, opts),
        data: data,
        params: changeset.params,
        hidden: hidden,
        options: opts
      }
    end
  end

  defp customize_changeset(nil, _, _, _), do: nil

  defp customize_changeset(changeset, original_changeset, type, attribute_or_relationship) do
    customize = original_changeset.context[:form][:customize_changeset]

    changeset =
      Ash.Changeset.set_context(changeset, %{
        customize_changeset: customize,
        form: %{
          path:
            (original_changeset.context[:form][:path] || []) ++ [attribute_or_relationship.name]
        }
      })

    case customize do
      nil ->
        changeset

      function when is_function(function, 3) ->
        function.(changeset, type, attribute_or_relationship)
    end
  end

  defp get_embedded({:array, type}), do: get_embedded(type)

  defp get_embedded(type) when is_atom(type) do
    if Ash.Resource.Info.embedded?(type) do
      type
    end
  end

  defp get_embedded(_), do: nil

  @impl true
  def input_validations(changeset, _, field) do
    attribute_or_argument =
      Ash.Resource.Info.attribute(changeset.resource, field) ||
        get_argument(changeset.action, field)

    if attribute_or_argument do
      [required: !attribute_or_argument.allow_nil?] ++ type_validations(attribute_or_argument)
    else
      []
    end
  end

  defp type_validations(%{type: Ash.Types.Integer, constraints: constraints}) do
    constraints
    |> Kernel.||([])
    |> Keyword.take([:max, :min])
    |> Keyword.put(:step, 1)
  end

  defp type_validations(%{type: Ash.Types.Decimal, constraints: constraints}) do
    constraints
    |> Kernel.||([])
    |> Keyword.take([:max, :min])
    |> Keyword.put(:step, "any")
  end

  defp type_validations(%{type: Ash.Types.String, constraints: constraints}) do
    if constraints[:trim?] do
      # We should consider using the `match` validation here, but we can't
      # add a title here, so we can't set an error message
      # min_length = to_string(constraints[:min_length])
      # max_length = to_string(constraints[:max_length])
      # [match: "(\S\s*){#{min_length},#{max_length}}"]
      []
    else
      validations =
        if constraints[:min_length] do
          [min_length: constraints[:min_length]]
        else
          []
        end

      if constraints[:min_length] do
        Keyword.put(constraints, :min_length, constraints[:min_length])
      else
        validations
      end
    end
  end

  defp type_validations(_), do: []

  defp form_for_errors(changeset, opts) do
    changeset.errors
    |> Enum.filter(&(Map.has_key?(&1, :field) || Map.has_key?(&1, :fields)))
    |> Enum.flat_map(fn
      %{field: field, message: {message, opts}} = error when not is_nil(field) ->
        [{field, {message, vars(error, opts)}}]

      %{field: field, message: message} = error when not is_nil(field) ->
        [{field, {message, vars(error, [])}}]

      %{field: field} = error when not is_nil(field) ->
        [{field, {Exception.message(error), vars(error, [])}}]

      %{fields: fields, message: {message, opts}} = error when is_list(fields) ->
        Enum.map(fields, fn field ->
          [{field, {message, vars(error, opts)}}]
        end)

      %{fields: fields, message: message} = error when is_list(fields) ->
        Enum.map(fields, fn field ->
          [{field, {message, vars(error, [])}}]
        end)

      %{fields: fields} = error when is_list(fields) ->
        message = Exception.message(error)

        Enum.map(fields, fn field ->
          {field, {message, vars(error, [])}}
        end)

      _ ->
        []
    end)
    |> filter_errors(changeset, opts)
  end

  defp filter_errors(errors, changeset, opts) do
    if opts[:all_errors?] || is_nil(changeset.action) do
      errors
    else
      Enum.filter(errors, fn {field, _} ->
        field in (opts[:error_keys] || []) ||
          has_non_empty_key?(changeset.params, field) ||
          has_non_empty_key?(changeset.params, to_string(field))
      end)
    end
  end

  defp has_non_empty_key?(params, field) do
    Map.has_key?(params, field) && params[field] not in [nil, "", []]
  end

  defp vars(%{vars: vars}, opts) do
    Keyword.merge(vars, opts)
  end

  defp vars(_, opts), do: opts

  defp form_for_method(%{action_type: :create}), do: "post"
  defp form_for_method(_), do: "put"

  defp form_for_name(resource) do
    resource
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end
end
