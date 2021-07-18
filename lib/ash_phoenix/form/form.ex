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

  ## LiveView
  `AshPhoenix.Form` (unlike ecto changeset based forms) expects to be reused throughout the lifecycle of the liveview.

  You can use phoenix events to add and remove form entries and `submit/2` to submit the form, like so:

  ```elixir
  alias MyApp.MyApi.{Comment, Post}

  def render(assigns) do
    ~L\"\"\"
    <%= f = form_for @form, "#", [phx_change: :validate, phx_submit: :save] %>
      <%= label f, :text %>
      <%= text_input f, :text %>
      <%= error_tag f, :text %>

      <%= for comment_form <- inputs_for(f, :comments) do %>
        <%= hidden_inputs_for(comment_form) %>
        <%= text_input comment_form, :text %>

        <%= for sub_comment_form <- inputs_for(comment_form, :sub_comments) do %>
          <%= hidden_inputs_for(sub_comment_form) %>
          <%= text_input sub_comment_form, :text %>
          <button phx-click="remove_form" phx-value-path="<%= sub_comment_form.name %>">Add Comment</button>
        <% end %>

        <button phx-click="remove_form" phx-value-path="<%= comment_form.name %>">Add Comment</button>
        <button phx-click="add_form" phx-value-path="<%= comment_form.name %>">Add Comment</button>
      <% end %>

      <button phx-click="add_form" phx-value-path="<%= comment_form.name %>">Add Comment</button>

      <%= submit "Save" %>
    </form>
    \"\"\"
  end

  def mount(%{"post_id" => post_id}, _session, socket) do
    post =
      Post
      |> MyApp.MyApi.get!(post_id)
      |> MyApi.load!(comments: [:sub_comments])

    form = AshPhoenix.Form.for_update(post, forms: [
      comments: [
        resource: Comment,
        data: post.comments,
        create_action: :create,
        update_action: :update
        forms: [
          sub_comments: [
            resource: Comment,
            data: &(&1.sub_comments),
            create_action: :create,
            update_action: :update
          ]
        ]
      ]
    ])

    {:ok, assign(socket, form: form)}
  end

  def handle_event("save", _params, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form) do
      {:ok, result} ->
        # Do something with the result, like redirect
      {:error, form} ->
        assign(socket, :form, form)
    end
  end

  def handle_event("add_form", %{"path" => path}, socket) do
    form = AshPhoenix.Form.add_form(socket.assigns.form, path)
    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("remove_form", %{"path" => path}) do
    form = AshPhoenix.Form.remove_form(socket.assigns.form, path)
    {:noreply, assign(socket, :form, form)}
  end
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
    errors: false,
    submitted_once?: false,
    just_submitted?: false
  ]

  @type t :: %__MODULE__{
          resource: Ash.Resource.t(),
          action: atom,
          type: :create | :update | :destroy | :read,
          params: map,
          source: Ash.Changeset.t() | Ash.Query.t(),
          data: nil | Ash.Resource.record(),
          form_keys: Keyword.t(),
          forms: map,
          method: String.t(),
          submit_errors: Keyword.t() | nil,
          opts: Keyword.t(),
          transform_errors:
            nil
            | (Ash.Changeset.t() | Ash.Query.t(), error :: Ash.Error.t() ->
                 [{field :: atom, message :: String.t(), substituations :: Keyword.t()}]),
          valid?: boolean,
          errors: boolean,
          submitted_once?: boolean,
          just_submitted?: boolean
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
      doc:
        "The html id of the form. Defaults to the value of `:as` if provided, otherwise \"form\""
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

  @nested_form_opts [
    type: [
      type: {:one_of, [:list, :single]},
      default: :single,
      doc: "The cardinality of the nested form."
    ],
    forms: [
      type: :keyword_list,
      doc: "Forms nested inside the current nesting level in all cases"
    ],
    for_type: [
      type: {:list, {:one_of, [:read, :create, :update]}},
      doc:
        "What action types the form applies for. Leave blank for it to apply to all action types."
    ],
    merge?: [
      type: :boolean,
      default: false,
      doc:
        "When building parameters, this input will be merged with its parent input. This allows for combining multiple forms into a single input."
    ],
    for: [
      type: :atom,
      doc:
        "When creating parameters for the action, the key that the forms should be gathered into. Defaults to the key used to configure the nested form. Ignored if `merge?` is `true`."
    ],
    resource: [
      type: :atom,
      doc:
        "The resource of the nested forms. Unnecessary if you are providing the `data` key, and not adding additional forms to this path."
    ],
    create_action: [
      type: :atom,
      doc:
        "The create action to use when building new forms. Only necessary if you want to use `add_form/3` with this path."
    ],
    update_action: [
      type: :atom,
      doc:
        "The update action to use when building forms for data. Only necessary if you supply the `data` key."
    ],
    data: [
      type: :any,
      doc: """
      The current value or values that should have update forms built by default.

      You can also provide a single argument function that will return the data based on the
      data of the parent form. This is important for multiple nesting levels of `:list` type
      forms, because the data depends on which parent is being rendered.
      """
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

  @doc "Calls the corresponding `for_*` function depending on the action type"
  def for_action(resource_or_data, action, opts) do
    {resource, data} =
      case resource_or_data do
        module when is_atom(resource_or_data) -> {module, module.__struct__()}
        %resource{} = data -> {resource, data}
      end

    type =
      if is_atom(action) do
        Ash.Resource.Info.action(resource, action).type
      else
        action.type
      end

    case type do
      :create ->
        for_create(resource, action, opts)

      :update ->
        for_update(data, action, opts)

      :destroy ->
        for_destroy(data, action, opts)

      :read ->
        for_read(resource, action, opts)
    end
  end

  @doc """
  Creates a form corresponding to a create action on a resource.

  Options:
  #{Ash.OptionsHelpers.docs(@for_opts)}

  Any *additional* options will be passed to the underlying call to `Ash.Changeset.for_create/4`. This means
  you can set things like the tenant/actor. These will be retained, and provided again when `Form.submit/3` is called.

  ## Nested Form Options

  To automatically determine the nested forms available for a given form, use `forms: [auto?: true]`.
  You can add additional nested forms by including them in the `forms` config alongside `auto?: true`.
  See the module documentation of `AshPhoenix.Forms.Auto` for more information. If you want to do some
  manipulation of the auto forms, you can also call `AshPhoenix.Forms.Auto.auto/2`, and then manipulate the
  result and pass it to the `forms` option.

  #{Ash.OptionsHelpers.docs(@nested_form_opts)}
  """
  @spec for_create(Ash.Resource.t(), action :: atom, opts :: Keyword.t()) :: t()
  def for_create(resource, action, opts \\ []) when is_atom(resource) do
    opts =
      opts
      |> add_auto(resource, action)
      |> update_opts()
      |> validate_opts_with_extra_keys(@for_opts)
      |> forms_for_type(:create)

    {forms, params} = handle_forms(opts[:params] || %{}, opts[:forms] || [], !!opts[:errors], [])

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
      id: opts[:id] || opts[:as] || "form",
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
    opts =
      opts
      |> add_auto(resource, action)
      |> update_opts()
      |> validate_opts_with_extra_keys(@for_opts)
      |> forms_for_type(:update)

    {forms, params} =
      handle_forms(opts[:params] || %{}, opts[:forms] || [], !!opts[:errors], [
        data | opts[:prev_data_trail] || []
      ])

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
      id: opts[:id] || opts[:as] || "form",
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
    opts =
      opts
      |> add_auto(resource, action)
      |> update_opts()
      |> validate_opts_with_extra_keys(@for_opts)
      |> forms_for_type(:destroy)

    {forms, params} =
      handle_forms(opts[:params] || %{}, opts[:forms] || [], !!opts[:errors], [
        data | opts[:prev_data_trail] || []
      ])

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
      id: opts[:id] || opts[:as] || "form",
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

  @doc """
  Creates a form corresponding to a read action on a resource.

  Options:
  #{Ash.OptionsHelpers.docs(@for_opts)}

  Any *additional* options will be passed to the underlying call to `Ash.Query.for_read/4`. This means
  you can set things like the tenant/actor. These will be retained, and provided again when `Form.submit/3` is called.

  Keep in mind that the `source` of the form in this case is a query, not a changeset. This means that, very likely,
  you would not want to use nested forms here. However, it could make sense if you had a query argument that was an
  embedded resource, so the capability remains.

  ## Nested Form Options

  #{Ash.OptionsHelpers.docs(@nested_form_opts)}
  """
  @spec for_read(Ash.Resource.t(), action :: atom, opts :: Keyword.t()) :: t()
  def for_read(resource, action, opts \\ []) when is_atom(resource) do
    opts =
      opts
      |> add_auto(resource, action)
      |> update_opts()
      |> validate_opts_with_extra_keys(@for_opts)
      |> forms_for_type(:read)

    {forms, params} = handle_forms(opts[:params] || %{}, opts[:forms] || [], !!opts[:errors], [])

    query_opts =
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
      type: :read,
      params: params,
      errors: opts[:errors],
      transform_errors: opts[:transform_errors],
      name: opts[:as] || "form",
      forms: forms,
      form_keys: List.wrap(opts[:forms]),
      id: opts[:id] || opts[:as] || "form",
      method: opts[:method] || form_for_method(:create),
      opts: opts,
      source:
        Ash.Query.for_read(
          resource,
          action,
          opts[:params] || %{},
          query_opts
        )
    }
    |> set_validity()
  end

  @doc "A utility to get the list of attributes the action underlying the form accepts"
  def attributes(form) do
    AshPhoenix.Form.Auto.accepted_attributes(form.resource, form.source.action)
  end

  @doc "A utility to get the list of arguments the action underlying the form accepts"
  def arguments(form) do
    action =
      case form.source.action do
        action when is_atom(action) ->
          Ash.Resource.Info.action(form.resource, action)

        action ->
          action
      end

    Enum.reject(action.arguments, & &1.private?)
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

    new_form =
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

        :read ->
          for_read(form.resource, form.action, new_form_opts)
      end

    %{
      new_form
      | submitted_once?: form.submitted_once?,
        submit_errors: form.submit_errors
    }
    |> update_all_forms(fn form ->
      %{form | just_submitted?: false}
    end)
  end

  @submit_opts [
    force?: [
      type: :boolean,
      default: false,
      doc: "Submit the form even if it is invalid in its current state."
    ],
    params: [
      type: :any,
      doc: "Override the params used for submit. Defaults to `AshPhoenix.Form.params(form)`"
    ],
    before_submit: [
      type: {:fun, 1},
      doc:
        "A function to apply to the source (changeset or query) just before submitting the action. Must return the modified changeset."
    ]
  ]

  @doc """
  Submits the form by calling the appropriate function on the provided api.

  For example, a form created with `for_update/3` will call `api.update(changeset)`, where
  changeset is the result of passing the `Form.params/3` into `Ash.Changeset.for_update/4`.

  If the submission returns an error, the resulting form can simply be rerendered. Any nested
  errors will be passed down to the corresponding form for that input.

  Options:

  #{Ash.OptionsHelpers.docs(@submit_opts)}
  """
  @spec submit(t(), Ash.Api.t(), Keyword.t()) ::
          {:ok, Ash.Resource.record()} | :ok | {:error, t()}
  def submit(form, api, opts \\ []) do
    opts = validate_opts_with_extra_keys(opts, @submit_opts)
    changeset_opts = Keyword.drop(form.opts, [:forms, :errors, :id, :method, :for, :as])
    before_submit = opts[:before_submit] || (& &1)

    if form.valid? || opts[:force?] do
      form = clear_errors(form)

      result =
        case form.type do
          :create ->
            form.resource
            |> Ash.Changeset.for_create(
              form.source.action.name,
              opts[:params] || params(form),
              changeset_opts
            )
            |> before_submit.()
            |> api.create()

          :update ->
            form.data
            |> Ash.Changeset.for_update(
              form.source.action.name,
              opts[:params] || params(form),
              changeset_opts
            )
            |> before_submit.()
            |> api.update()

          :destroy ->
            form.data
            |> Ash.Changeset.for_destroy(
              form.source.action.name,
              opts[:params] || params(form),
              changeset_opts
            )
            |> before_submit.()
            |> api.destroy()

          :read ->
            form.resource
            |> Ash.Query.for_read(
              form.source.action.name,
              opts[:params] || params(form),
              changeset_opts
            )
            |> before_submit.()
            |> api.create()
        end

      case result do
        {:error, %{query: query} = error} when form.type == :read ->
          query = %{query | errors: []}

          errors =
            error
            |> List.wrap()
            |> Enum.flat_map(&expand_error/1)

          {:error,
           set_action_errors(
             %{form | source: query},
             errors
           )
           |> update_all_forms(fn form ->
             %{form | just_submitted?: true, submitted_once?: true}
           end)}

        {:error, %{changeset: changeset} = error} when form.type != :read ->
          changeset = %{changeset | errors: []}

          errors =
            error
            |> List.wrap()
            |> Enum.flat_map(&expand_error/1)

          {:error,
           set_action_errors(
             %{form | source: changeset},
             errors
           )
           |> update_all_forms(fn form ->
             %{form | just_submitted?: true, submitted_once?: true}
           end)}

        other ->
          other
      end
    else
      {:error,
       form
       |> update_all_forms(fn form -> %{form | submitted_once?: true, just_submitted?: true} end)
       |> synthesize_action_errors()}
    end
  end

  @spec update_form(t(), list(atom | integer) | String.t(), (t() -> t())) :: t()
  def update_form(form, path, func) do
    path =
      case path do
        [] ->
          []

        path when is_list(path) ->
          path

        path ->
          parse_path!(form, path)
      end

    case path do
      [] ->
        func.(form)

      [atom, integer | rest] when is_atom(atom) and is_integer(integer) ->
        new_forms =
          form.forms
          |> Map.update!(atom, fn nested_forms ->
            List.update_at(nested_forms, integer, &update_form(&1, rest, func))
          end)

        %{form | forms: new_forms}

      [atom | rest] ->
        new_forms =
          form.forms
          |> Map.update!(atom, &update_form(&1, rest, func))

        %{form | forms: new_forms}
    end
  end

  @spec errors_for(t(), list(atom | integer) | String.t(), type :: :simple | :raw | :plaintext) ::
          [{atom, {String.t(), Keyword.t()}}] | [String.t()] | map | nil
  def errors_for(form, path, type \\ :raw) do
    path =
      case path do
        [] ->
          []

        path when is_list(path) ->
          path

        path ->
          parse_path!(form, path)
      end

    case path do
      [] ->
        if form.submit_errors do
          case type do
            :raw ->
              form.submit_errors || []

            :simple ->
              Map.new(form.submit_errors || [], fn {field, {message, vars}} ->
                message = replace_vars(message, vars)

                {field, message}
              end)

            :plaintext ->
              Enum.map(form.submit_errors || [], fn {field, {message, vars}} ->
                message = replace_vars(message, vars)

                "#{field}: " <> message
              end)
          end
        else
          []
        end

      [atom, integer | rest] when is_atom(atom) and is_integer(integer) ->
        form.forms
        |> Map.get(atom)
        |> Enum.at(integer)
        |> errors_for(rest, type)

      [atom | rest] ->
        form.forms
        |> Map.get(atom)
        |> errors_for(rest, type)
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

        :read ->
          form.resource
          |> Ash.Query.for_read(form.source.action.name, params(form), changeset_opts)
          |> api.read!()
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

          if form.form_keys[key][:merge?] do
            Map.merge(nested_params || %{}, params)
          else
            Map.put(params, to_string(config[:for] || key), nested_params)
          end

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
    ],
    type: [
      type: {:one_of, [:read, :create]},
      default: :create,
      doc:
        "If `type` is set to `:read`, the form will be created for a read action. A hidden field will be set in the form called `_form_type` to track this information."
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

  defp forms_for_type(opts, type) do
    if opts[:forms] do
      Keyword.update!(opts, :forms, fn forms ->
        Enum.filter(forms, fn {_key, config} ->
          is_nil(config[:for_type]) || type in config[:for_type]
        end)
      end)
    else
      opts
    end
  end

  defp replace_vars(message, vars) do
    Enum.reduce(vars || [], message, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  @doc false
  def update_opts(opts) do
    if opts[:forms] do
      Keyword.update!(opts, :forms, fn forms ->
        Enum.map(forms, fn
          {:auto?, value} ->
            {:auto?, value}

          {key, opts} ->
            if opts[:updater] do
              {key, Keyword.delete(opts[:updater].(opts), :updater)}
            else
              {key, opts}
            end
        end)
      end)
    else
      opts
    end
  end

  defp update_all_forms(form, func) do
    form = func.(form)

    form
    |> func.()
    |> Map.update!(:forms, fn forms ->
      Map.new(forms, fn {key, value} ->
        case value do
          %__MODULE__{} = form ->
            {key, update_all_forms(form, func)}

          list when is_list(list) ->
            {key, Enum.map(list, &update_all_forms(&1, func))}

          other ->
            {key, other}
        end
      end)
    end)
  end

  defp do_remove_form(form, [key], _trail) when not is_integer(key) do
    unless form.form_keys[key] do
      raise AshPhoenix.Form.NoFormConfigured,
        field: key,
        available: Keyword.keys(form.form_keys || [])
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
      raise AshPhoenix.Form.NoFormConfigured,
        field: key,
        available: Keyword.keys(form.form_keys || [])
    end

    new_config =
      form.form_keys
      |> Keyword.update!(key, fn config ->
        if config[:data] do
          Keyword.update!(config, :data, fn data ->
            cond do
              is_function(data, 1) ->
                fn original_data -> List.delete_at(data.(original_data), i) end

              is_function(data, 2) ->
                fn original_data, trail -> List.delete_at(data.(original_data, trail), i) end

              true ->
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
      raise AshPhoenix.Form.NoFormConfigured,
        field: key,
        available: Keyword.keys(form.form_keys || [])
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
      raise AshPhoenix.Form.NoFormConfigured,
        field: key,
        available: Keyword.keys(form.form_keys || [])
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
    config =
      form.form_keys[key] ||
        raise AshPhoenix.Form.NoFormConfigured,
          field: key,
          available: Keyword.keys(form.form_keys || [])

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
            cond do
              is_function(data, 1) ->
                fn original_data -> [nil | data.(original_data)] end

              is_function(data, 2) ->
                fn original_data, trail -> [nil | data.(original_data, trail)] end

              true ->
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
        {resource, action} = add_form_resource_and_action(opts, config, key, trail)

        new_form =
          for_action(resource, action,
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

  defp add_form_resource_and_action(opts, config, key, trail) do
    action =
      case opts[:type] || :create do
        :create ->
          config[:create_action] ||
            raise AshPhoenix.Form.NoActionConfigured,
              path: Enum.reverse(trail, [key]),
              action: :create

        :update ->
          config[:update_action] ||
            raise AshPhoenix.Form.NoActionConfigured,
              path: Enum.reverse(trail, [key]),
              action: :update

        :destroy ->
          config[:destroy_action] ||
            raise AshPhoenix.Form.NoActionConfigured,
              path: Enum.reverse(trail, [key]),
              action: :destroy

        :read ->
          config[:read_action] ||
            raise AshPhoenix.Form.NoActionConfigured,
              path: Enum.reverse(trail, [key]),
              action: :read
      end

    resource =
      case opts[:type] || :create do
        :create ->
          config[:create_resource] || config[:resource] ||
            raise AshPhoenix.Form.NoResourceConfigured, path: Enum.reverse(trail, [key])

        :update ->
          config[:update_resource] || config[:resource] ||
            raise AshPhoenix.Form.NoResourceConfigured, path: Enum.reverse(trail, [key])

        :destroy ->
          config[:destroy_resource] || config[:resource] ||
            raise AshPhoenix.Form.NoResourceConfigured, path: Enum.reverse(trail, [key])

        :read ->
          config[:read_resource] || config[:resource] ||
            raise AshPhoenix.Form.NoResourceConfigured, path: Enum.reverse(trail, [key])
      end

    {resource, action}
  end

  defp add_auto(opts, resource, action) do
    if opts[:forms][:auto?] do
      Keyword.update!(opts, :forms, fn forms ->
        auto =
          resource
          |> AshPhoenix.Form.Auto.auto(action)
          |> Enum.reject(fn {key, _} -> Keyword.has_key?(forms, key) end)

        forms
        |> Keyword.delete(:auto?)
        |> Enum.concat(auto)
      end)
    else
      opts
    end
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
            end
          end

        {key, new_forms}
      end)

    %{form | submit_errors: transform_errors(form, errors, path), forms: new_forms}
  end

  defp synthesize_action_errors(form) do
    new_forms =
      form.forms
      |> Map.new(fn {key, forms} ->
        new_forms =
          if is_list(forms) do
            Enum.map(forms, fn form ->
              synthesize_action_errors(form)
            end)
          else
            if forms do
              synthesize_action_errors(forms)
            end
          end

        {key, new_forms}
      end)

    errors =
      form.source.errors
      |> List.wrap()
      |> Enum.flat_map(&expand_error/1)

    %{form | submit_errors: transform_errors(form, errors), forms: new_forms}
  end

  defp expand_error(%class_mod{} = error)
       when class_mod in [
              Ash.Error.Forbidden,
              Ash.Error.Framework,
              Ash.Error.Invalid,
              Ash.Error.Unkonwn
            ] do
    Enum.flat_map(error.errors, &expand_error/1)
  end

  defp expand_error(other), do: List.wrap(other)

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

  @doc """
  A utility for parsing paths of nested forms in query encoded format.

  For example:

  ```elixir
  parse_path!(form, "post[comments][0][sub_comments][0])

  [:comments, 0, :sub_comments, 0]
  ```
  """
  def parse_path!(%{name: name} = form, original_path) do
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

  defp handle_forms(params, form_keys, error?, prev_data_trail, trail \\ []) do
    Enum.reduce(form_keys, {%{}, params}, fn {key, opts}, {forms, params} ->
      case fetch_key(params, key) do
        {:ok, form_params} ->
          handle_form_with_params(
            forms,
            params,
            form_params,
            opts,
            key,
            trail,
            prev_data_trail,
            error?
          )

        :error ->
          handle_form_without_params(forms, params, opts, key, trail, prev_data_trail, error?)
      end
    end)
  end

  defp handle_form_without_params(forms, params, opts, key, trail, prev_data_trail, error?) do
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
              if Enum.at(prev_data_trail, 0) do
                case call_data(opts[:data], prev_data_trail) do
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
            for_action(data, update_action,
              errors: error?,
              prev_data_trail: prev_data_trail,
              forms: opts[:forms] || []
            )
          else
            Enum.map(
              data,
              &for_action(&1, update_action,
                errors: error?,
                prev_data_trail: prev_data_trail,
                forms: opts[:forms] || []
              )
            )
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

  defp handle_form_with_params(
         forms,
         params,
         form_params,
         opts,
         key,
         trail,
         prev_data_trail,
         error?
       ) do
    # if form type is destroy, then we should destroy instead of update
    # merge?: true option on forms that tells it to merge params w/ the parent
    form_values =
      if Keyword.has_key?(opts, :data) do
        handle_form_with_params_and_data(opts, form_params, key, trail, prev_data_trail, error?)
      else
        handle_form_with_params_and_no_data(
          opts,
          form_params,
          key,
          trail,
          prev_data_trail,
          error?
        )
      end

    {Map.put(forms, key, form_values), Map.delete(params, [key, to_string(key)])}
  end

  defp handle_form_with_params_and_no_data(opts, form_params, key, trail, prev_data_trail, error?) do
    if (opts[:type] || :single) == :single do
      if form_params["_form_type"] == "read" do
        read_action =
          opts[:read_action] ||
            raise AshPhoenix.Form.NoActionConfigured,
              path: Enum.reverse(trail, Enum.reverse(trail, [key])),
              action: :read

        resource =
          opts[:read_resource] || opts[:resource] ||
            raise AshPhoenix.Form.NoResourceConfigured,
              path: Enum.reverse(trail, [key])

        for_action(resource, read_action,
          params: form_params,
          forms: opts[:forms] || [],
          errors: error?,
          prev_data_trail: prev_data_trail
        )
      else
        create_action =
          opts[:create_action] ||
            raise AshPhoenix.Form.NoActionConfigured,
              path: Enum.reverse(trail, Enum.reverse(trail, [key])),
              action: :create

        resource =
          opts[:create_resource] || opts[:resource] ||
            raise AshPhoenix.Form.NoResourceConfigured,
              path: Enum.reverse(trail, [key])

        for_action(resource, create_action,
          params: form_params,
          forms: opts[:forms] || [],
          errors: error?,
          prev_data_trail: prev_data_trail
        )
      end
    else
      form_params
      |> indexed_list()
      |> Enum.map(fn form_params ->
        if form_params["_form_type"] == "read" do
          read_action =
            opts[:read_action] ||
              raise AshPhoenix.Form.NoActionConfigured,
                path: Enum.reverse(trail, Enum.reverse(trail, [key])),
                action: :read

          resource =
            opts[:read_resource] || opts[:resource] ||
              raise AshPhoenix.Form.NoResourceConfigured,
                path: Enum.reverse(trail, [key])

          for_action(resource, read_action,
            params: form_params,
            forms: opts[:forms] || [],
            errors: error?,
            prev_data_trail: prev_data_trail
          )
        else
          create_action =
            opts[:create_action] ||
              raise AshPhoenix.Form.NoActionConfigured,
                path: Enum.reverse(trail, Enum.reverse(trail, [key])),
                action: :create

          resource =
            opts[:create_resource] || opts[:resource] ||
              raise AshPhoenix.Form.NoResourceConfigured,
                path: Enum.reverse(trail, [key])

          for_action(resource, create_action,
            params: form_params,
            forms: opts[:forms] || [],
            errors: error?,
            prev_data_trail: prev_data_trail
          )
        end
      end)
    end
  end

  defp handle_form_with_params_and_data(opts, form_params, key, trail, prev_data_trail, error?) do
    data =
      if is_function(opts[:data]) do
        if Enum.at(prev_data_trail, 0) do
          call_data(opts[:data], prev_data_trail)
        else
          nil
        end
      else
        opts[:data]
      end

    if (opts[:type] || :single) == :single do
      if data || form_params["_form_type"] == "read" do
        case form_params["_form_type"] || "update" do
          # "read" ->

          "update" ->
            update_action =
              opts[:update_action] ||
                raise AshPhoenix.Form.NoActionConfigured,
                  path: Enum.reverse(trail, Enum.reverse(trail, [key])),
                  action: :update

            for_action(data, update_action,
              params: form_params,
              forms: opts[:forms] || [],
              errors: error?,
              prev_data_trail: prev_data_trail
            )

          "destroy" ->
            destroy_action =
              opts[:destroy_action] ||
                raise AshPhoenix.Form.NoActionConfigured,
                  path: Enum.reverse(trail, Enum.reverse(trail, [key])),
                  action: :destroy

            for_action(data, destroy_action,
              params: form_params,
              forms: opts[:forms] || [],
              errors: error?,
              prev_data_trail: prev_data_trail
            )
        end
      else
        case form_params["_form_type"] || "create" do
          "create" ->
            create_action =
              opts[:create_action] ||
                raise AshPhoenix.Form.NoActionConfigured,
                  path: Enum.reverse(trail, Enum.reverse(trail, [key])),
                  action: :create_action

            resource =
              opts[:create_resource] || opts[:resource] ||
                raise AshPhoenix.Form.NoResourceConfigured,
                  path: Enum.reverse(trail, [key])

            for_action(resource, create_action,
              params: form_params,
              forms: opts[:forms] || [],
              errors: error?,
              prev_data_trail: prev_data_trail
            )

          "read" ->
            resource =
              opts[:read_resource] || opts[:resource] ||
                raise AshPhoenix.Form.NoResourceConfigured,
                  path: Enum.reverse(trail, [key])

            read_action =
              opts[:read_action] ||
                raise AshPhoenix.Form.NoActionConfigured,
                  path: Enum.reverse(trail, Enum.reverse(trail, [key])),
                  action: :read

            for_action(resource, read_action,
              params: form_params,
              forms: opts[:forms] || [],
              errors: error?,
              prev_data_trail: prev_data_trail
            )
        end
      end
    else
      data = List.wrap(data)

      form_params
      |> indexed_list()
      |> Enum.reduce({[], List.wrap(data)}, fn form_params, {forms, data} ->
        if form_params["_form_type"] == "read" do
          resource =
            opts[:read_resource] || opts[:resource] ||
              raise AshPhoenix.Form.NoResourceConfigured,
                path: Enum.reverse(trail, [key])

          read_action =
            opts[:read_action] ||
              raise AshPhoenix.Form.NoActionConfigured,
                path: Enum.reverse(trail, Enum.reverse(trail, [key])),
                action: :read

          form =
            for_action(resource, read_action,
              params: form_params,
              forms: opts[:forms] || [],
              errors: error?,
              prev_data_trail: prev_data_trail
            )

          {[form | forms], data}
        else
          case data do
            [nil | rest] ->
              create_action =
                opts[:create_action] ||
                  raise AshPhoenix.Form.NoActionConfigured,
                    path: Enum.reverse(trail, Enum.reverse(trail, [key])),
                    action: :create_action

              resource =
                opts[:create_resource] || opts[:resource] ||
                  raise AshPhoenix.Form.NoResourceConfigured,
                    path: Enum.reverse(trail, [key])

              form =
                for_action(resource, create_action,
                  params: form_params,
                  forms: opts[:forms] || [],
                  errors: error?,
                  prev_data_trail: prev_data_trail
                )

              {[form | forms], rest}

            [data | rest] ->
              form =
                if form_params["_form_type"] == "destroy" do
                  destroy_action =
                    opts[:destroy_action] ||
                      raise AshPhoenix.Form.NoActionConfigured,
                        path: Enum.reverse(trail, Enum.reverse(trail, [key])),
                        action: :destroy

                  for_action(data, destroy_action,
                    params: form_params,
                    forms: opts[:forms] || [],
                    errors: error?,
                    prev_data_trail: prev_data_trail
                  )
                else
                  update_action =
                    opts[:update_action] ||
                      raise AshPhoenix.Form.NoActionConfigured,
                        path: Enum.reverse(trail, Enum.reverse(trail, [key])),
                        action: :update

                  for_action(data, update_action,
                    params: form_params,
                    forms: opts[:forms] || [],
                    errors: error?,
                    prev_data_trail: prev_data_trail
                  )
                end

              {[form | forms], rest}

            [] ->
              resource =
                opts[:create_resource] || opts[:resource] ||
                  raise AshPhoenix.Form.NoResourceConfigured,
                    path: Enum.reverse(trail, [key])

              create_action =
                opts[:create_action] ||
                  raise AshPhoenix.Form.NoActionConfigured,
                    path: Enum.reverse(trail, Enum.reverse(trail, [key])),
                    action: :create

              form =
                for_action(resource, create_action,
                  params: form_params,
                  forms: opts[:forms] || [],
                  errors: error?,
                  prev_data_trail: prev_data_trail
                )

              {[form | forms], []}
          end
        end
      end)
      |> elem(0)
      |> Enum.reverse()
    end
  end

  defp call_data(func, prev_data_trail) do
    if is_function(func, 1) do
      func.(Enum.at(prev_data_trail, 0))
    else
      func.(Enum.at(prev_data_trail, 0), Enum.drop(prev_data_trail, 1))
    end
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
      hidden =
        if form.type in [:update, :destroy] do
          form.data
          |> Map.take(Ash.Resource.Info.primary_key(form.resource))
          |> Enum.to_list()
        else
          []
        end

      hidden = Keyword.put(hidden, :_form_type, to_string(form.type))

      errors =
        if form.errors do
          if form.just_submitted? do
            form.submit_errors
          else
            transform_errors(form, form.source.errors, [])
          end
        else
          []
        end

      %Phoenix.HTML.Form{
        source: form,
        impl: __MODULE__,
        id: form.id,
        name: form.name,
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
        raise AshPhoenix.Form.NoFormConfigured,
          field: field,
          available: Keyword.keys(form.form_keys || [])
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
      |> List.wrap()
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
      with :error <- get_changing_value(changeset, field),
           :error <- Ash.Changeset.fetch_argument(changeset, field),
           :error <- Map.fetch(changeset.params, Atom.to_string(field)),
           :error <- Map.fetch(changeset.data, field) do
        nil
      else
        {:ok, value} ->
          value
      end
    end

    def input_value(%{source: %Ash.Query{} = query}, _form, field) do
      case Ash.Query.fetch_argument(query, field) do
        {:ok, value} ->
          value

        :error ->
          Map.get(query.params, to_string(field))
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

    @impl true
    def input_validations(%{source: %Ash.Query{} = query}, _, field) do
      argument = get_argument(query.action, field)

      if argument do
        [required: !argument.allow_nil?] ++ type_validations(argument)
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
