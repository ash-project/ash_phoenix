defmodule AshPhoenix.Form do
  @moduledoc """
  A module to allow you to fluidly use resources with phoenix forms.

  The general workflow is, with either liveview or phoenix forms:

  1. Create a form with `AshPhoenix.Form`
  2. Render that form with Phoenix's `form_for` (or, if using surface, <Form>)
  3. To validate the form (e.g with `on-change` for liveview), pass the input to `AshPhoenix.Form.validate(form, params)`
  4. On form submission, pass the input to `AshPhoenix.Form.validate(form, params)` and then use `AshPhoenix.Form.submid(form, ApiModule)`

  If your resource action accepts related data, (for example a managed relationship argument, or an embedded resource attribute), you can
  use Phoenix's `inputs_for` for that field, *but* you must explicitly configure the behavior of it using the `forms` option.
  See `Form.for_create/3` for more.

  For example:

  ```elixir
  form =
    user
    |> AshPhoenix.Form.for_update(:update, forms: [
      profile: [
        resource: MyApp.Profile,
        data: user.profile,
        create_action: :create,
        update_action: :update
        forms: [
          emails: [
            data: user.profile.emails,
            resource: MyApp.UserEmail,
            create_action: :create,
            update_action: :update
          ]
        ]
      ]
    ])
  ```
  """
  defstruct [
    :resource,
    :action,
    :type,
    :params,
    :source,
    :name,
    :data,
    :form_keys,
    :forms,
    :method,
    :submit_errors,
    :opts,
    :id,
    :transform_errors,
    valid?: false,
    errors: false
  ]

  @type t :: %__MODULE__{
          resource: Ash.Resource.t(),
          action: atom,
          type: :create | :update | :destroy,
          params: map,
          source: Ash.Changeset.t(),
          data: nil | Ash.Resource.record(),
          form_keys: Keyword.t(),
          forms: map,
          method: String.t(),
          submit_errors: Keyword.t() | nil,
          opts: Keyword.t(),
          transform_errors:
            nil
            | (Ash.Changeset.t(), error :: Ash.Error.t() ->
                 [{field :: atom, message :: String.t(), substituations :: Keyword.t()}]),
          valid?: boolean,
          errors: boolean
        }

  @for_opts [
    forms: [
      type: :keyword_list,
      doc: "Nested form configurations. See for_create/3 docs for more."
    ],
    as: [
      type: :string,
      default: "form",
      doc:
        "The name of the form in the submitted params. You will need to pull the form params out using this key."
    ],
    id: [
      type: :string,
      default: "form",
      doc: "The html id of the form."
    ],
    transform_errors: [
      type: {:fun, 2},
      doc: """
      Allows for manual manipulation and transformation of errors.

      If possible, try to implement `AshPhoenix.FormData.Error` for the error (if it as a custom one, for example).
      If that isn't possible, you can provide this function which will get the changeset and the error, and should
      return a list of ash phoenix formatted errors, e.g `[{field :: atom, message :: String.t(), substituations :: Keyword.t()}]`
      """
    ],
    method: [
      type: :string,
      doc:
        "The http method to associate with the form. Defaults to `post` for creates, and `put` for everything else."
    ]
  ]

  @doc false
  defp validate_opts_with_extra_keys(opts, schema) do
    keys = Keyword.keys(schema)

    {opts, extra} = Keyword.split(opts, keys)

    opts = Ash.OptionsHelpers.validate!(opts, schema)

    Keyword.merge(opts, extra)
  end

  import AshPhoenix.FormData.Helpers

  @doc """
  Creates a form corresponding to a create action on a resource.

  Options:
  #{Ash.OptionsHelpers.docs(@for_opts)}

  Any *additional* options will be passed to the underlying call to `Ash.Changeset.for_create/4`. This means
  you can set things like the tenant/actor. These will be retained, and provided again when `Form.submit/3` is called.
  """
  @spec for_create(Ash.Resource.t(), action :: atom, opts :: Keyword.t()) :: t()
  def for_create(resource, action, opts \\ []) when is_atom(resource) do
    opts = validate_opts_with_extra_keys(opts, @for_opts)
    {forms, params} = handle_forms(opts[:params] || %{}, opts[:forms] || [], !!opts[:errors], nil)

    changeset_opts =
      Keyword.drop(opts, [
        :forms,
        :transform_errors,
        :errors,
        :id,
        :method,
        :for,
        :as
      ])

    %__MODULE__{
      resource: resource,
      action: action,
      type: :create,
      params: params,
      errors: opts[:errors],
      transform_errors: opts[:transform_errors],
      name: opts[:as] || "form",
      forms: forms,
      form_keys: List.wrap(opts[:forms]),
      id: opts[:id] || "form",
      method: opts[:method] || form_for_method(:create),
      opts: opts,
      source:
        Ash.Changeset.for_create(
          resource,
          action,
          opts[:params] || %{},
          changeset_opts
        )
    }
    |> set_validity()
  end

  @doc """
  Creates a form corresponding to an update action on a record.

  Options:
  #{Ash.OptionsHelpers.docs(@for_opts)}

  Any *additional* options will be passed to the underlying call to `Ash.Changeset.for_update/4`. This means
  you can set things like the tenant/actor. These will be retained, and provided again when `Form.submit/3` is called.
  """
  @spec for_update(Ash.Resource.record(), action :: atom, opts :: Keyword.t()) :: t()
  def for_update(%resource{} = data, action, opts \\ []) do
    {forms, params} =
      handle_forms(opts[:params] || %{}, opts[:forms] || [], !!opts[:errors], data)

    changeset_opts =
      Keyword.drop(opts, [:forms, :transform_errors, :errors, :id, :method, :for, :as])

    %__MODULE__{
      resource: resource,
      data: data,
      action: action,
      type: :update,
      params: params,
      errors: opts[:errors],
      transform_errors: opts[:transform_errors],
      forms: forms,
      form_keys: List.wrap(opts[:forms]),
      method: opts[:method] || form_for_method(:update),
      opts: opts,
      id: opts[:id] || "form",
      name: opts[:as] || "form",
      source:
        Ash.Changeset.for_update(
          data,
          action,
          params,
          changeset_opts
        )
    }
    |> set_validity()
  end

  @doc """
  Creates a form corresponding to a destroy action on a record.

  Options:
  #{Ash.OptionsHelpers.docs(@for_opts)}

  Any *additional* options will be passed to the underlying call to `Ash.Changeset.for_destroy/4`. This means
  you can set things like the tenant/actor. These will be retained, and provided again when `Form.submit/3` is called.
  """
  @spec for_destroy(Ash.Resource.record(), action :: atom, opts :: Keyword.t()) :: t()
  def for_destroy(%resource{} = data, action, opts \\ []) do
    {forms, params} =
      handle_forms(opts[:params] || %{}, opts[:forms] || [], !!opts[:errors], data)

    changeset_opts =
      Keyword.drop(opts, [:forms, :transform_errors, :errors, :id, :method, :for, :as])

    %__MODULE__{
      resource: resource,
      data: data,
      action: action,
      type: :destroy,
      params: params,
      errors: opts[:errors],
      transform_errors: opts[:transform_errors],
      forms: forms,
      name: opts[:as] || "form",
      id: opts[:id] || "form",
      method: opts[:method] || form_for_method(:destroy),
      form_keys: List.wrap(opts[:forms]),
      opts: opts,
      source:
        Ash.Changeset.for_destroy(
          data,
          action,
          params,
          changeset_opts
        )
    }
    |> set_validity()
  end

  @validate_opts [
    errors: [
      type: :boolean,
      default: true,
      doc: "Set to false to hide errors after validation"
    ]
  ]

  @doc """
  Validates the parameters against the form.

  Options:

  #{Ash.OptionsHelpers.docs(@validate_opts)}
  """
  @spec validate(t(), map, Keyword.t()) :: t()
  def validate(form, new_params, opts \\ []) do
    opts = Ash.OptionsHelpers.validate!(opts, @validate_opts)

    new_form_opts =
      form.opts
      |> Keyword.put(:errors, opts[:errors])
      |> Keyword.put(:params, new_params)
      |> Keyword.put(:forms, form.form_keys)

    case form.type do
      :create ->
        for_create(
          form.resource,
          form.action,
          new_form_opts
        )

      :update ->
        for_update(form.data, form.action, new_form_opts)

      :destroy ->
        for_destroy(form.data, form.action, new_form_opts)
    end
  end

  @doc """
  Submits the form by calling the appropriate function on the provided api.

  For example, a form created with `for_update/3` will call `api.update(changeset)`, where
  changeset is the result of passing the `Form.params/3` into `Ash.Changeset.for_update/4`.

  If the submission returns an error, the resulting form can simply be rerendered. Any nested
  errors will be passed down to the corresponding form for that input.
  """
  @spec submit(t(), Ash.Api.t(), Keyword.t()) ::
          {:ok, Ash.Resource.record()} | :ok | {:error, t()}
  def submit(form, api, opts \\ []) do
    changeset_opts = Keyword.drop(form.opts, [:forms, :errors, :id, :method, :for, :as])

    form = clear_errors(form)

    if form.valid? || opts[:force?] do
      result =
        case form.type do
          :create ->
            form.resource
            |> Ash.Changeset.for_create(form.source.action.name, params(form), changeset_opts)
            |> api.create()

          :update ->
            form.data
            |> Ash.Changeset.for_update(form.source.action.name, params(form), changeset_opts)
            |> api.update()

          :destroy ->
            form.data
            |> Ash.Changeset.for_destroy(form.source.action.name, params(form), changeset_opts)
            |> api.destroy()
        end

      case result do
        {:error, %{changeset: changeset} = error} ->
          changeset = %{changeset | errors: []}

          errors =
            error
            |> List.wrap()
            |> Enum.flat_map(&expand_error/1)

          {:error, set_action_errors(%{form | source: changeset}, errors)}

        other ->
          other
      end
    else
      {:error, form}
    end
  end

  @doc """
  Same as `submit/3`, but raises an error if the submission fails.
  """
  def submit!(form, api, opts \\ []) do
    changeset_opts = Keyword.drop(form.opts, [:forms, :errors, :id, :method, :for, :as])

    form = clear_errors(form)

    if form.source.valid? || opts[:force?] do
      case form.type do
        :create ->
          form.resource
          |> Ash.Changeset.for_create(form.source.action.name, params(form), changeset_opts)
          |> api.create!()

        :update ->
          form.data
          |> Ash.Changeset.for_update(form.source.action.name, params(form), changeset_opts)
          |> api.update!()

        :destroy ->
          form.data
          |> Ash.Changeset.for_destroy(form.source.action.name, params(form), changeset_opts)
          |> api.destroy!()
      end
    else
      raise Ash.Error.to_ash_error(form.source.errors)
    end
  end

  @doc """
  Returns the parameters from the form that would be submitted to the action.

  This can be useful if you want to get the parameters and manipulate them/build a custom changeset
  afterwards.
  """
  @spec params(t()) :: map
  def params(form) do
    form_keys =
      form.form_keys
      |> Keyword.keys()
      |> Enum.flat_map(&[&1, to_string(&1)])

    Enum.reduce(form.form_keys, Map.drop(form.params, form_keys), fn {key, config}, params ->
      case config[:type] || :single do
        :single ->
          nested_params =
            if form.forms[key] do
              params(form.forms[key])
            else
              nil
            end

          Map.put(params, to_string(config[:for] || key), nested_params)

        :list ->
          for_name = to_string(config[:for] || key)

          params
          |> Map.put_new(for_name, [])
          |> Map.update!(for_name, fn current ->
            current ++ Enum.map(form.forms[key] || [], &params(&1 || []))
          end)
      end
    end)
  end

  @add_form_opts [
    prepend: [
      type: :boolean,
      default: false,
      doc:
        "If specified, the form is placed at the beginning of the list instead of the end of the list"
    ],
    params: [
      type: :any,
      default: %{},
      doc: "The initial parameters to add the form with."
    ]
  ]

  @doc """
  Adds a new form at the provided path.

  Doing this requires that the form has a `create_action` and a `resource` configured.

  `path` can be one of two things:

  1. A list of atoms and integers that lead to a form in the `forms` option provided. `[:posts, 0, :comments]` to add a comment to the first post.
  2. The html name of the form, e.g `form[posts][0][comments]` to mimic the above

  #{Ash.OptionsHelpers.docs(@add_form_opts)}
  """
  @spec add_form(t(), String.t() | list(atom | integer), Keyword.t()) :: t()
  def add_form(form, path, opts \\ []) do
    opts = Ash.OptionsHelpers.validate!(opts, @add_form_opts)

    if is_binary(path) do
      do_add_form(form, parse_path!(form, path), opts, [])
    else
      do_add_form(form, List.wrap(path), opts, [])
    end
  end

  @doc """
  Removes a form at the provided path.

  See `add_form/3` for more information on the `path` argument.

  If you are not using liveview, and you want to support removing forms that were created based on the `data`
  option from the browser, you'll need to include in the form submission a custom list of strings to remove, and
  then manually iterate over them in your controller, for example:

  ```elixir
  Enum.reduce(removed_form_paths, form, &AshPhoenix.Form.remove_form(&2, &1))
  ```
  """
  def remove_form(form, path) do
    if is_binary(path) do
      do_remove_form(form, parse_path!(form, path), [])
    else
      do_remove_form(form, List.wrap(path), [])
    end
  end

  defp do_remove_form(form, [key], _trail) when not is_integer(key) do
    unless form.form_keys[key] do
      raise AshPhoenix.Form.NoFormConfigured, field: key
    end

    new_config =
      form.form_keys
      |> Keyword.update!(key, fn config ->
        if config[:data] do
          Keyword.put(config, :data, nil)
        else
          config
        end
      end)

    new_forms = Map.put(form.forms, key, nil)

    %{form | forms: new_forms, form_keys: new_config}
  end

  defp do_remove_form(form, [key, i], _trail) when is_integer(i) do
    unless form.form_keys[key] do
      raise AshPhoenix.Form.NoFormConfigured, field: key
    end

    new_config =
      form.form_keys
      |> Keyword.update!(key, fn config ->
        if config[:data] do
          Keyword.update!(config, :data, fn data ->
            if is_function(data) do
              fn original_data -> List.delete_at(data.(original_data), i) end
            else
              List.delete_at(data, i)
            end
          end)
        else
          config
        end
      end)

    new_forms =
      form.forms
      |> Map.put_new(key, [])
      |> Map.update!(key, fn forms ->
        List.delete_at(forms, i)
      end)

    %{form | forms: new_forms, form_keys: new_config}
  end

  defp do_remove_form(form, [key, i | rest], trail) when is_integer(i) do
    unless form.form_keys[key] do
      raise AshPhoenix.Form.NoFormConfigured, field: key
    end

    new_forms =
      form.forms
      |> Map.put_new(key, [])
      |> Map.update!(key, fn forms ->
        List.update_at(forms, i, &do_remove_form(&1, rest, [i, key | trail]))
      end)

    %{form | forms: new_forms}
  end

  defp do_remove_form(_form, path, trail) do
    raise ArgumentError, message: "Invalid Path: #{inspect(Enum.reverse(trail, path))}"
  end

  defp do_add_form(form, [key, i | rest], opts, trail) when is_integer(i) do
    unless form.form_keys[key] do
      raise AshPhoenix.Form.NoFormConfigured, field: key
    end

    new_forms =
      form.forms
      |> Map.put_new(key, [])
      |> Map.update!(key, fn forms ->
        List.update_at(forms, i, &do_add_form(&1, rest, opts, [i, key | trail]))
      end)

    %{form | forms: new_forms}
  end

  defp do_add_form(form, [key], opts, trail) do
    config = form.form_keys[key] || raise AshPhoenix.Form.NoFormConfigured, field: key

    default =
      case config[:type] || :single do
        :single ->
          nil

        :list ->
          []
      end

    new_config =
      form.form_keys
      |> Keyword.update!(key, fn config ->
        if config[:data] do
          Keyword.update!(config, :data, fn data ->
            if is_function(data) do
              fn original_data -> [nil | data.(original_data)] end
            else
              [nil | data]
            end
          end)
        else
          config
        end
      end)

    new_forms =
      form.forms
      |> Map.put_new(key, default)
      |> Map.update!(key, fn forms ->
        create_action =
          config[:create_action] ||
            raise AshPhoenix.Form.NoActionConfigured,
              path: Enum.reverse(trail, [key]),
              action: :create

        resource =
          config[:resource] ||
            raise AshPhoenix.Form.NoResourceConfigured, path: Enum.reverse(trail, [key])

        new_form =
          for_create(resource, create_action,
            params: opts[:params] || %{},
            forms: config[:forms] || []
          )

        case config[:type] || :single do
          :single ->
            %{new_form | id: form.id <> "[#{key}]"}

          :list ->
            if opts[:prepend] do
              [new_form | forms]
            else
              forms ++ [new_form]
            end
            |> Enum.with_index()
            |> Enum.map(fn {nested_form, index} ->
              %{nested_form | id: form.id <> "[#{key}][#{index}]"}
            end)
        end
      end)

    %{form | forms: new_forms, form_keys: new_config}
  end

  defp do_add_form(_form, path, _opts, trail) do
    raise ArgumentError, message: "Invalid Path: #{inspect(Enum.reverse(trail, path))}"
  end

  @spec set_validity(t()) :: t()
  defp set_validity(form) do
    %{form | valid?: valid?(form)}
  end

  defp valid?(form) do
    if form.source.valid? do
      Enum.empty?(form.forms) ||
        Enum.all?(form.forms, fn {_, v} ->
          v
          |> List.wrap()
          |> Enum.all?(&valid?/1)
        end)
    end
  end

  defp set_action_errors(form, errors, path \\ []) do
    new_forms =
      form.forms
      |> Map.new(fn {key, forms} ->
        config = form.form_keys[key]

        new_forms =
          if is_list(forms) do
            forms
            |> Enum.with_index()
            |> Enum.map(fn {form, index} ->
              set_action_errors(form, errors, path ++ [config[:for] || key, index])
            end)
          else
            if forms do
              set_action_errors(forms, errors, path ++ [config[:for] || key])
            else
              {key, forms}
            end
          end

        {key, new_forms}
      end)

    %{form | submit_errors: transform_errors(form, errors, path), forms: new_forms}
  end

  defp expand_error(%class_mod{} = error)
       when class_mod in [
              Ash.Error.Forbidden,
              Ash.Error.Framework,
              Ash.Error.Invalid,
              Ash.Error.Unkonwn
            ] do
    error.errors
  end

  defp clear_errors(nil), do: nil

  defp clear_errors(forms) when is_list(forms) do
    Enum.map(forms, &clear_errors/1)
  end

  defp clear_errors(form) do
    %{
      form
      | forms:
          Map.new(form.forms, fn {k, v} ->
            {k, clear_errors(v)}
          end),
        source: %{
          form.source
          | errors: []
        }
    }
  end

  defp parse_path!(%{name: name} = form, original_path) do
    path =
      original_path
      |> Plug.Conn.Query.decode()
      |> decoded_to_list()

    case path do
      [^name | rest] ->
        do_decode_path(form, original_path, rest)

      _other ->
        raise ArgumentError,
              "Form name does not match beginning of path: #{inspect(original_path)}"
    end
  end

  defp do_decode_path(_, _, []), do: []

  defp do_decode_path(forms, original_path, [key | rest]) when is_list(forms) do
    case Integer.parse(key) do
      {index, ""} ->
        case Enum.at(forms, index) do
          nil ->
            raise "Invalid Path: #{original_path}"

          form ->
            [index | do_decode_path(form, original_path, rest)]
        end

      _ ->
        raise "Invalid Path: #{original_path}"
    end
  end

  defp do_decode_path(form, original_path, [key | rest]) do
    form.form_keys
    |> Enum.find_value(fn {search_key, value} ->
      if to_string(search_key) == key do
        {search_key, value}
      end
    end)
    |> case do
      nil ->
        raise "Invalid Path: #{original_path}"

      {key, config} ->
        if config[:type] || :single == :single do
          [key | do_decode_path(form.forms[key], original_path, rest)]
        else
          [key | do_decode_path(form.forms[key] || [], original_path, rest)]
        end
    end
  end

  defp decoded_to_list(""), do: []

  defp decoded_to_list(value) do
    {key, rest} = Enum.at(value, 0)

    [key | decoded_to_list(rest)]
  end

  defp handle_forms(params, form_keys, error?, prev_data, trail \\ []) do
    Enum.reduce(form_keys, {%{}, params}, fn {key, opts}, {forms, params} ->
      case fetch_key(params, key) do
        {:ok, form_params} ->
          form_values =
            if Keyword.has_key?(opts, :data) do
              data =
                if is_function(opts[:data]) do
                  if prev_data do
                    opts[:data].(prev_data)
                  else
                    nil
                  end
                else
                  opts[:data]
                end

              if (opts[:type] || :single) == :single do
                update_action =
                  opts[:update_action] ||
                    raise AshPhoenix.Form.NoActionConfigured,
                      path: Enum.reverse(trail, Enum.reverse(trail, [key])),
                      action: :update

                for_update(data, update_action,
                  params: form_params,
                  forms: opts[:forms] || [],
                  errors: error?
                )
              else
                form_params
                |> indexed_list()
                |> Enum.reduce({[], List.wrap(data)}, fn form_params, {forms, data} ->
                  case data do
                    [nil | rest] ->
                      create_action =
                        opts[:create_action] ||
                          raise AshPhoenix.Form.NoActionConfigured,
                            path: Enum.reverse(trail, Enum.reverse(trail, [key])),
                            action: :create_action

                      resource =
                        opts[:resource] ||
                          raise AshPhoenix.Form.NoResourceConfigured,
                            path: Enum.reverse(trail, [key])

                      form =
                        for_create(resource, create_action,
                          params: form_params,
                          forms: opts[:forms] || [],
                          errors: error?
                        )

                      {[form | forms], rest}

                    [data | rest] ->
                      update_action =
                        opts[:update_action] ||
                          raise AshPhoenix.Form.NoActionConfigured,
                            path: Enum.reverse(trail, Enum.reverse(trail, [key])),
                            action: :update

                      form =
                        for_update(data, update_action,
                          params: form_params,
                          forms: opts[:forms] || [],
                          errors: error?
                        )

                      {[form | forms], rest}

                    [] ->
                      resource =
                        opts[:resource] ||
                          raise AshPhoenix.Form.NoResourceConfigured,
                            path: Enum.reverse(trail, [key])

                      create_action =
                        opts[:create_action] ||
                          raise AshPhoenix.Form.NoActionConfigured,
                            path: Enum.reverse(trail, Enum.reverse(trail, [key])),
                            action: :create

                      form =
                        for_create(resource, create_action,
                          params: form_params,
                          forms: opts[:forms] || [],
                          errors: error?
                        )

                      {[form | forms], []}
                  end
                end)
                |> elem(0)
                |> Enum.reverse()
              end
            else
              create_action =
                opts[:create_action] ||
                  raise AshPhoenix.Form.NoActionConfigured,
                    path: Enum.reverse(trail, Enum.reverse(trail, [key])),
                    action: :create

              resource =
                opts[:resource] ||
                  raise AshPhoenix.Form.NoResourceConfigured,
                    path: Enum.reverse(trail, [key])

              if (opts[:type] || :single) == :single do
                for_create(resource, create_action,
                  params: form_params,
                  forms: opts[:forms] || [],
                  errors: error?
                )
              else
                form_params
                |> indexed_list()
                |> Enum.map(fn form_params ->
                  for_create(resource, create_action,
                    params: form_params,
                    forms: opts[:forms] || [],
                    errors: error?
                  )
                end)
              end
            end

          {Map.put(forms, key, form_values), Map.delete(params, [key, to_string(key)])}

        :error ->
          form_values =
            if Keyword.has_key?(opts, :data) do
              update_action =
                opts[:update_action] ||
                  raise AshPhoenix.Form.NoActionConfigured,
                    path: Enum.reverse(trail, Enum.reverse(trail, [key])),
                    action: :update

              data =
                if opts[:data] do
                  if is_function(opts[:data]) do
                    if prev_data do
                      case opts[:data].(prev_data) do
                        %Ash.NotLoaded{} ->
                          raise AshPhoenix.Form.NoDataLoaded,
                            path: Enum.reverse(trail, Enum.reverse(trail, [key]))

                        other ->
                          other
                      end
                    else
                      nil
                    end
                  else
                    opts[:data]
                  end
                end

              if data do
                if (opts[:type] || :single) == :single do
                  for_update(data, update_action, errors: error?)
                else
                  Enum.map(data, &for_update(&1, update_action, errors: error?))
                end
              else
                nil
              end
            else
              if (opts[:type] || :single) == :single do
                nil
              else
                []
              end
            end

          {Map.put(forms, key, form_values), params}
      end
    end)
  end

  defp indexed_list(map) when is_map(map) do
    map
    |> Map.keys()
    |> Enum.map(&String.to_integer/1)
    |> Enum.sort()
    |> Enum.map(&map[to_string(&1)])
  rescue
    _ ->
      List.wrap(map)
  end

  defp indexed_list(other), do: List.wrap(other)

  defp fetch_key(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} -> {:ok, value}
      :error -> Map.fetch(params, to_string(key))
    end
  end

  defp form_for_method(:create), do: "post"
  defp form_for_method(_), do: "put"

  defimpl Phoenix.HTML.FormData do
    import AshPhoenix.FormData.Helpers

    @impl true
    def to_form(form, opts) do
      name = form.name || to_string(form_for_name(form.resource))

      hidden =
        if form.type in [:update, :destroy] do
          form.data
          |> Map.take(Ash.Resource.Info.primary_key(form.resource))
          |> Enum.to_list()
        else
          []
        end

      errors =
        if form.errors do
          form.submit_errors ||
            transform_errors(form, form.source.errors)
        else
          []
        end

      %Phoenix.HTML.Form{
        source: form,
        impl: __MODULE__,
        id: form.id,
        name: name,
        errors: errors,
        data: form.data,
        params: form.params,
        hidden: hidden,
        options: Keyword.put_new(opts, :method, form.method)
      }
    end

    @impl true
    def to_form(form, _phoenix_form, field, opts) do
      unless Keyword.has_key?(form.form_keys, field) do
        raise AshPhoenix.Form.NoFormConfigured, field: field
      end

      case form.form_keys[field][:type] || :single do
        :single ->
          if form.forms[field] do
            form.forms[field]
            |> to_form(opts)
            |> Map.put(:name, form.name <> "[#{field}]")
            |> Map.put(:id, form.id <> "_#{field}")
          end

        :list ->
          form.forms[field]
          |> Kernel.||([])
          |> Enum.with_index()
          |> Enum.map(fn {nested_form, index} ->
            nested_form
            |> to_form(opts)
            |> Map.put(:name, form.name <> "[#{field}][#{index}]")
            |> Map.put(:id, form.id <> "_#{field}_#{index}")
          end)
      end
    end

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

    @impl true
    def input_value(%{source: %Ash.Changeset{} = changeset}, _form, field) do
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

    @impl true
    def input_validations(%{source: %Ash.Changeset{} = changeset}, _, field) do
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

    defp get_changing_value(changeset, field) do
      with :error <- Map.fetch(changeset.attributes, field),
           :error <- Map.fetch(changeset.params, field) do
        Map.fetch(changeset.params, to_string(field))
      end
    end
  end
end
