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
  See `for_create/3` for more.

  For example:

  ```elixir
  form =
    user
    |> AshPhoenix.Form.for_update(:update,
      api: MyApi,
      forms: [
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

    form = AshPhoenix.Form.for_update(post,
      api: MyApp.MyApi,
      forms: [
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

  # In order to use the `add_form` and `remove_form` helpers, you
  # need to make sure that you are validating the form on change
  def handle_event("validate", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    # You can also skip errors by setting `errors: false` if you only want to show errors on submit
    # form = AshPhoenix.Form.validate(socket.assigns.form, params, errors: false)

    {:ok, assign(socket, :form, form)}
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
    :api,
    :method,
    :submit_errors,
    :opts,
    :id,
    :transform_errors,
    :original_data,
    touched_forms: MapSet.new(),
    data_updates: [],
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
          data_updates: [
            {:prepend, list(atom | integer)}
            | {:remove, list(atom | integer)}
          ],
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
      doc: "Nested form configurations. See `for_create/3` \"Nested Form Options\" docs for more."
    ],
    api: [
      type: :atom,
      doc:
        "The api module to use for form submission. If not set, calls to `Form.submit/2` will fail"
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
      type: :any,
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
  See the module documentation of `AshPhoenix.Form.Auto` for more information. If you want to do some
  manipulation of the auto forms, you can also call `AshPhoenix.Form.Auto.auto/2`, and then manipulate the
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

    manage_relationship_source_changeset =
      if Enum.any?(opts[:forms] || [], fn {_, config} ->
           config[:managed_relationship]
         end) do
        resource
        |> Ash.Changeset.new()
        |> set_managed_relationship_context(opts)
        |> Ash.Changeset.for_create(
          action,
          opts[:params] || %{},
          changeset_opts
        )
      end

    name = opts[:as] || "form"
    id = opts[:id] || opts[:as] || "form"

    {forms, params} =
      handle_forms(
        opts[:params] || %{},
        opts[:forms] || [],
        !!opts[:errors],
        [],
        manage_relationship_source_changeset,
        name,
        id,
        opts[:data_updates] || []
      )

    %__MODULE__{
      resource: resource,
      action: action,
      type: :create,
      api: opts[:api],
      params: params,
      errors: opts[:errors],
      transform_errors: opts[:transform_errors],
      name: name,
      forms: forms,
      form_keys: List.wrap(opts[:forms]),
      data_updates: opts[:data_updates] || [],
      id: id,
      touched_forms: touched_forms(forms, params, opts),
      method: opts[:method] || form_for_method(:create),
      opts: opts,
      source:
        resource
        |> Ash.Changeset.new()
        |> set_managed_relationship_context(opts)
        |> Ash.Changeset.for_create(
          action,
          params,
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

    changeset_opts =
      Keyword.drop(opts, [:forms, :transform_errors, :errors, :id, :method, :for, :as])

    manage_relationship_source_changeset =
      if Enum.any?(opts[:forms] || [], fn {_, config} ->
           config[:managed_relationship]
         end) do
        data
        |> Ash.Changeset.new()
        |> set_managed_relationship_context(opts)
        |> Ash.Changeset.for_update(
          action,
          opts[:params] || %{},
          changeset_opts
        )
      end

    name = opts[:as] || "form"
    id = opts[:id] || opts[:as] || "form"

    {forms, params} =
      handle_forms(
        opts[:params] || %{},
        opts[:forms] || [],
        !!opts[:errors],
        [
          data | opts[:prev_data_trail] || []
        ],
        manage_relationship_source_changeset,
        name,
        id,
        opts[:data_updates] || []
      )

    %__MODULE__{
      resource: resource,
      data: data,
      action: action,
      type: :update,
      api: opts[:api],
      params: params,
      errors: opts[:errors],
      transform_errors: opts[:transform_errors],
      forms: forms,
      form_keys: List.wrap(opts[:forms]),
      original_data: data,
      method: opts[:method] || form_for_method(:update),
      data_updates: opts[:data_updates] || [],
      touched_forms: touched_forms(forms, params, opts),
      opts: opts,
      id: id,
      name: name,
      source:
        data
        |> Ash.Changeset.new()
        |> set_managed_relationship_context(opts)
        |> Ash.Changeset.for_update(
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

    changeset_opts =
      Keyword.drop(opts, [:forms, :transform_errors, :errors, :id, :method, :for, :as])

    manage_relationship_source_changeset =
      if Enum.any?(opts[:forms] || [], fn {_, config} ->
           config[:managed_relationship]
         end) do
        data
        |> Ash.Changeset.new()
        |> set_managed_relationship_context(opts)
        |> Ash.Changeset.for_update(
          action,
          opts[:params] || %{},
          changeset_opts
        )
      end

    name = opts[:as] || "form"
    id = opts[:id] || opts[:as] || "form"

    {forms, params} =
      handle_forms(
        opts[:params] || %{},
        opts[:forms] || [],
        !!opts[:errors],
        [
          data | opts[:prev_data_trail] || []
        ],
        manage_relationship_source_changeset,
        name,
        id,
        opts[:data_updates] || []
      )

    %__MODULE__{
      resource: resource,
      data: data,
      action: action,
      type: :destroy,
      params: params,
      errors: opts[:errors],
      transform_errors: opts[:transform_errors],
      data_updates: opts[:data_updates] || [],
      original_data: data,
      forms: forms,
      name: name,
      id: id,
      api: opts[:api],
      method: opts[:method] || form_for_method(:destroy),
      touched_forms: touched_forms(forms, params, opts),
      form_keys: List.wrap(opts[:forms]),
      opts: opts,
      source:
        data
        |> Ash.Changeset.new()
        |> set_managed_relationship_context(opts)
        |> Ash.Changeset.for_destroy(
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

    name = opts[:as] || "form"
    id = opts[:id] || opts[:as] || "form"

    {forms, params} =
      handle_forms(
        opts[:params] || %{},
        opts[:forms] || [],
        !!opts[:errors],
        [],
        nil,
        name,
        id,
        opts[:data_updates] || []
      )

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
      name: name,
      forms: forms,
      form_keys: List.wrap(opts[:forms]),
      id: id,
      api: opts[:api],
      method: opts[:method] || form_for_method(:create),
      data_updates: opts[:data_updates] || [],
      opts: opts,
      touched_forms: touched_forms(forms, params, opts),
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
      |> Keyword.put(:data_updates, form.data_updates)
      |> Keyword.put(:touched_forms, form.touched_forms)

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
        submit_errors: nil,
        original_data: form.original_data
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
      doc: """
      If specified, `validate/3` is called with the new params before submitting the form.

      This is a shortcut to avoid needing to explicitly validate before every submit.

      For example:

      ```elixir
      form
      |> AshPhoenix.Form.validate(params)
      |> AshPhoenix.Form.submit()
      ```

      Is the same as:

      ```elixir
      form
      |> AshPhoenix.Form.submit(params: params)
      ```
      """
    ],
    before_submit: [
      type: {:fun, 1},
      doc:
        "A function to apply to the source (changeset or query) just before submitting the action. Must return the modified changeset."
    ]
  ]

  @doc """
  Submits the form by calling the appropriate function on the configured api.

  For example, a form created with `for_update/3` will call `api.update(changeset)`, where
  changeset is the result of passing the `Form.params/3` into `Ash.Changeset.for_update/4`.

  If the submission returns an error, the resulting form can simply be rerendered. Any nested
  errors will be passed down to the corresponding form for that input.

  Options:

  #{Ash.OptionsHelpers.docs(@submit_opts)}
  """
  @spec submit(t(), Keyword.t()) ::
          {:ok, Ash.Resource.record()} | :ok | {:error, t()}
  def submit(form, opts \\ []) do
    form =
      if opts[:params] do
        AshPhoenix.Form.validate(
          form,
          opts[:params],
          Keyword.take(opts, Keyword.keys(@validate_opts))
        )
      else
        form
      end

    opts = validate_opts_with_extra_keys(opts, @submit_opts)
    changeset_opts = Keyword.drop(form.opts, [:forms, :errors, :id, :method, :for, :as])
    before_submit = opts[:before_submit] || (& &1)

    if form.valid? || opts[:force?] do
      form = clear_errors(form)

      unless form.api do
        raise """
        No Api configured, but one is required to submit the form.

        For example:


            Form.for_create(Resource, :action, api: MyApp.MyApi)
        """
      end

      result =
        case form.type do
          :create ->
            form.resource
            |> Ash.Changeset.for_create(
              form.source.action.name,
              params(form),
              changeset_opts
            )
            |> before_submit.()
            |> form.api.create()

          :update ->
            form.original_data
            |> Ash.Changeset.for_update(
              form.source.action.name,
              params(form),
              changeset_opts
            )
            |> before_submit.()
            |> form.api.update()

          :destroy ->
            form.original_data
            |> Ash.Changeset.for_destroy(
              form.source.action.name,
              params(form),
              changeset_opts
            )
            |> before_submit.()
            |> form.api.destroy()

          :read ->
            form.resource
            |> Ash.Query.for_read(
              form.source.action.name,
              params(form),
              changeset_opts
            )
            |> before_submit.()
            |> form.api.create()
        end

      case result do
        {:error, %Ash.Error.Invalid.NoSuchResource{resource: resource}} ->
          raise """
          Resource #{inspect(resource)} not found in api #{inspect(form.api)}
          """

        {:error, %{query: query} = error} when form.type == :read ->
          if opts[:raise?] do
            raise Ash.Error.to_error_class(query.errors, query: query)
          else
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
          end

        {:error, %{changeset: changeset} = error} when form.type != :read ->
          if opts[:raise?] do
            raise Ash.Error.to_error_class(changeset.errors, changeset: changeset)
          else
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
          end

        other ->
          other
      end
    else
      if opts[:raise?] do
        case form.source do
          %Ash.Query{} = query ->
            raise Ash.Error.to_error_class(query.errors, query: query)

          %Ash.Changeset{} = changeset ->
            raise Ash.Error.to_error_class(changeset.errors, changeset: changeset)
        end
      else
        {:error,
         form
         |> update_all_forms(fn form -> %{form | submitted_once?: true, just_submitted?: true} end)
         |> synthesize_action_errors()}
      end
    end
  end

  @doc """
  Same as `submit/2`, but raises an error if the submission fails.
  """
  @spec submit!(t(), Keyword.t()) :: Ash.Resource.record() | :ok | no_return
  def submit!(form, opts \\ []) do
    case submit(form, Keyword.put(opts, :raise?, true)) do
      {:ok, value} ->
        value

      :ok ->
        :ok

      _ ->
        :error
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

  @spec get_form(t(), list(atom | integer) | String.t()) :: t() | nil
  def get_form(form, path) do
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
        form

      [atom, integer | rest] when is_atom(atom) and is_integer(integer) ->
        form.forms
        |> Map.get(atom)
        |> List.wrap()
        |> Enum.at(integer)
        |> case do
          nil ->
            nil

          form ->
            get_form(form, rest)
        end

      [atom | rest] ->
        form.forms
        |> Map.get(atom)
        |> case do
          %__MODULE__{} = form ->
            get_form(form, rest)

          _ ->
            nil
        end
    end
  end

  @errors_opts [
    format: [
      type: {:one_of, [:simple, :raw, :plaintext]},
      default: :simple,
      doc: """
      Values:
          - `:raw` - `[field:, {message, substitutions}}]` (for translation)
          - `:simple` - `[field: "message w/ variables substituted"]`
          - `:plaintext` - `["field: message w/ variables substituted"]`
      """
    ],
    for_path: [
      type: :any,
      default: [],
      doc: """
      The path of the form you want errors for, either as a list or as a string, e.g `[:comments, 0]` or `form[comments][0]`
      Passing `:all` will cause this function to return a map of path to its errors, like so:

      ```elixir
      %{[:comments, 0] => [body: "is invalid"], ...}
      ```
      """
    ]
  ]

  @doc """
  Returns the errors on the form.

  By default, only errors on the form being passed in (not nested forms) are provided.
  Use `for_path` to get errors for nested forms.

  #{Ash.OptionsHelpers.docs(@errors_opts)}
  """
  @spec errors(t(), Keyword.t()) ::
          [{atom, {String.t(), Keyword.t()}}] | [String.t()] | [{atom, String.t()}]
  def errors(form, opts \\ []) do
    opts = validate_opts_with_extra_keys(opts, @errors_opts)

    case opts[:for_path] do
      :all ->
        gather_errors(form, opts[:format])

      [] ->
        form
        |> Phoenix.HTML.Form.form_for("foo")
        |> Map.get(:errors)
        |> List.wrap()
        |> format_errors(opts[:format])

      path ->
        form
        |> gather_errors(opts[:format])
        |> Map.get(path)
        |> List.wrap()
    end
  end

  defp format_errors(errors, :raw), do: errors

  defp format_errors(errors, :simple) do
    Enum.map(errors, fn {field, {message, vars}} ->
      message = replace_vars(message, vars)

      {field, message}
    end)
  end

  defp format_errors(errors, :plaintext) do
    Enum.map(errors, fn {field, {message, vars}} ->
      message = replace_vars(message, vars)

      "#{field}: " <> message
    end)
  end

  defp gather_errors(form, format, acc \\ %{}, trail \\ []) do
    errors = errors(form, format: format)

    acc =
      if Enum.empty?(errors) do
        acc
      else
        Map.put(acc, trail, errors)
      end

    Enum.reduce(form.forms, acc, fn {key, forms}, acc ->
      case forms do
        [] ->
          acc

        nil ->
          acc

        forms when is_list(forms) ->
          forms
          |> Enum.with_index()
          |> Enum.reduce(acc, fn {form, i}, acc ->
            gather_errors(form, format, acc, trail ++ [key, i])
          end)

        form ->
          gather_errors(form, format, acc, trail ++ [key])
      end
    end)
  end

  @spec errors_for(t(), list(atom | integer) | String.t(), type :: :simple | :raw | :plaintext) ::
          [{atom, {String.t(), Keyword.t()}}] | [String.t()] | map | nil
  @deprecated "Use errors/2 instead"
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
  Sets the data of the form, in addition to the data of the underlying source, if applicable.

  Queries do not track data (because that wouldn't make sense), so this will not update the data
  for read actions
  """
  def set_data(form, data) do
    case form.source do
      %Ash.Changeset{} = source ->
        %{form | data: data, source: %{source | data: data}}

      %Ash.Query{} ->
        %{form | data: data}
    end
  end

  @doc """
  Gets the value for a given field in the form.
  """
  @spec value(t(), atom) :: any()
  def value(form, field) do
    form
    |> Phoenix.HTML.Form.form_for("form")
    |> Phoenix.HTML.Form.input_value(field)
  end

  @doc """
  Returns the parameters from the form that would be submitted to the action.

  This can be useful if you want to get the parameters and manipulate them/build a custom changeset
  afterwards.
  """
  @spec params(t()) :: map
  def params(form, opts \\ []) do
    hidden? = opts[:hidden?] || false
    indexed_lists? = opts[:indexed_lists?] || false

    form_keys =
      form.form_keys
      |> Keyword.keys()
      |> Enum.flat_map(&[&1, to_string(&1)])

    params = Map.drop(form.params, form_keys)

    params =
      if hidden? do
        hidden = Phoenix.HTML.Form.form_for(form, "foo").hidden
        hidden_stringified = hidden |> Map.new(fn {field, value} -> {to_string(field), value} end)
        Map.merge(hidden_stringified, params)
      else
        params
      end

    form.form_keys
    |> Enum.filter(fn {key, _} ->
      MapSet.member?(form.touched_forms, to_string(key))
    end)
    |> Enum.reduce(params, fn {key, config}, params ->
      case config[:type] || :single do
        :single ->
          if form.forms[key] do
            nested_params =
              if form.forms[key] do
                params(form.forms[key], opts)
              else
                nil
              end

            if form.form_keys[key][:merge?] do
              Map.merge(nested_params || %{}, params)
            else
              Map.put(params, to_string(config[:for] || key), nested_params)
            end
          else
            Map.put(params, to_string(config[:for] || key), nil)
          end

        :list ->
          for_name = to_string(config[:for] || key)

          if indexed_lists? do
            params
            |> Map.put_new(for_name, %{})
            |> Map.update!(for_name, fn current ->
              max =
                current |> Map.keys() |> Enum.map(&String.to_integer/1) |> Enum.max(fn -> -1 end)

              form.forms[key]
              |> Enum.reduce({current, max + 1}, fn form, {current, i} ->
                {Map.put(current, to_string(i), params(form, opts)), i + 1}
              end)
              |> elem(0)
            end)
          else
            params
            |> Map.put_new(for_name, [])
            |> Map.update!(for_name, fn current ->
              current ++ Enum.map(form.forms[key] || [], &params(&1, opts))
            end)
          end
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

    {form, path} =
      if is_binary(path) do
        path = parse_path!(form, path)
        {do_add_form(form, path, opts, [], form.transform_errors), path}
      else
        path = List.wrap(path)
        {do_add_form(form, path, opts, [], form.transform_errors), path}
      end

    %{
      form
      | data_updates: [{:prepend, path} | form.data_updates],
        touched_forms: touched_forms(form.forms, opts[:params] || %{}, form.opts)
    }
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
    {form, path} =
      if is_binary(path) do
        path = parse_path!(form, path)
        {do_remove_form(form, path, []), path}
      else
        path = List.wrap(path)
        {do_remove_form(form, path, []), path}
      end

    %{form | data_updates: [{:remove, path} | form.data_updates]}
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

  defp replace_vars(message, vars) do
    Enum.reduce(vars || [], message, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", to_string(value))
    end)
  end

  defp touched_forms(forms, params, opts) do
    touched_forms = opts[:touched_forms] || MapSet.new()

    touched_forms =
      Enum.reduce(forms, touched_forms, fn {key, form_or_forms}, touched_forms ->
        if form_or_forms in [nil, []] do
          touched_forms
        else
          MapSet.put(touched_forms, to_string(key))
        end
      end)

    touched =
      if is_map(params) do
        params["_touched"]
      end

    case touched do
      touched_from_params when is_binary(touched_from_params) ->
        touched_from_params
        |> String.split(",")
        |> Enum.reduce(touched_forms, fn key, touched_forms ->
          MapSet.put(touched_forms, key)
        end)

      _ ->
        touched_forms
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

  defp do_remove_form(form, [key], trail) when not is_integer(key) do
    unless form.form_keys[key] do
      raise AshPhoenix.Form.NoFormConfigured,
        field: key,
        available: Keyword.keys(form.form_keys || []),
        path: Enum.reverse(trail)
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

    %{
      form
      | forms: new_forms,
        form_keys: new_config,
        opts: Keyword.put(form.opts, :forms, new_config)
    }
  end

  defp do_remove_form(form, [key, i], trail) when is_integer(i) do
    unless form.form_keys[key] do
      raise AshPhoenix.Form.NoFormConfigured,
        field: key,
        available: Keyword.keys(form.form_keys || []),
        path: Enum.reverse(trail)
    end

    new_config = do_remove_data(form, key, i)

    new_forms =
      form.forms
      |> Map.put_new(key, [])
      |> Map.update!(key, fn forms ->
        forms
        |> List.delete_at(i)
        |> Enum.with_index()
        |> Enum.map(fn {nested_form, i} ->
          %{nested_form | name: form.name <> "[#{key}][#{i}]", id: form.id <> "_#{key}_#{i}"}
        end)
      end)

    %{
      form
      | forms: new_forms,
        form_keys: new_config,
        opts: Keyword.put(form.opts, :forms, new_config)
    }
  end

  defp do_remove_form(form, [key, i | rest], trail) when is_integer(i) do
    unless form.form_keys[key] do
      raise AshPhoenix.Form.NoFormConfigured,
        field: key,
        available: Keyword.keys(form.form_keys || []),
        path: Enum.reverse(trail)
    end

    new_forms =
      form.forms
      |> Map.put_new(key, [])
      |> Map.update!(key, fn forms ->
        List.update_at(forms, i, &do_remove_form(&1, rest, [i, key | trail]))
      end)

    %{form | forms: new_forms}
  end

  defp do_remove_form(form, [key | rest], trail) do
    unless form.form_keys[key] do
      raise AshPhoenix.Form.NoFormConfigured,
        field: key,
        available: Keyword.keys(form.form_keys || []),
        path: Enum.reverse(trail)
    end

    new_forms =
      form.forms
      |> Map.put_new(key, [])
      |> Map.update!(key, &do_remove_form(&1, rest, [key | trail]))

    %{form | forms: new_forms}
  end

  defp do_remove_form(_form, path, trail) do
    raise ArgumentError, message: "Invalid Path: #{inspect(Enum.reverse(trail, path))}"
  end

  defp do_add_form(form, [key, i | rest], opts, trail, transform_errors) when is_integer(i) do
    unless form.form_keys[key] do
      raise AshPhoenix.Form.NoFormConfigured,
        field: key,
        available: Keyword.keys(form.form_keys || []),
        path: Enum.reverse(trail)
    end

    new_forms =
      form.forms
      |> Map.put_new(key, [])
      |> Map.update!(key, fn forms ->
        List.update_at(
          forms,
          i,
          &do_add_form(&1, rest, opts, [i, key | trail], transform_errors)
        )
      end)

    %{form | forms: new_forms}
  end

  defp do_add_form(form, [key], opts, trail, transform_errors) do
    config =
      form.form_keys[key] ||
        raise AshPhoenix.Form.NoFormConfigured,
          field: key,
          available: Keyword.keys(form.form_keys || []),
          path: Enum.reverse(trail)

    default =
      case config[:type] || :single do
        :single ->
          nil

        :list ->
          []
      end

    new_config =
      if opts[:prepend] && config[:type] == :list do
        do_prepend_data(form, key)
      else
        form.form_keys
      end

    new_forms =
      form.forms
      |> Map.put_new(key, default)
      |> Map.update!(key, fn forms ->
        {resource, action} = add_form_resource_and_action(opts, config, key, trail)

        new_form =
          for_action(resource, action,
            params: opts[:params] || %{},
            forms: config[:forms] || [],
            manage_relationship_source: manage_relationship_source(form, config),
            transform_errors: transform_errors
          )

        case config[:type] || :single do
          :single ->
            %{new_form | name: form.name <> "[#{key}]", id: form.id <> "_#{key}"}

          :list ->
            forms = List.wrap(forms)

            if opts[:prepend] do
              [new_form | forms]
            else
              forms ++ [new_form]
            end
            |> Enum.with_index()
            |> Enum.map(fn {nested_form, index} ->
              %{
                nested_form
                | name: form.name <> "[#{key}][#{index}]",
                  id: form.id <> "_#{key}_#{index}"
              }
            end)
        end
      end)

    %{
      form
      | forms: new_forms,
        form_keys: new_config,
        opts: Keyword.put(form.opts, :forms, new_config)
    }
  end

  defp do_add_form(form, [key | rest], opts, trail, transform_errors) do
    unless form.form_keys[key] do
      raise AshPhoenix.Form.NoFormConfigured,
        field: key,
        available: Keyword.keys(form.form_keys || []),
        path: Enum.reverse(trail)
    end

    new_forms =
      form.forms
      |> Map.put_new(key, [])
      |> Map.update!(key, &do_add_form(&1, rest, opts, [key | trail], transform_errors))

    %{form | forms: new_forms}
  end

  defp do_add_form(_form, path, _opts, trail, _) do
    raise ArgumentError, message: "Invalid Path: #{inspect(Enum.reverse(trail, path))}"
  end

  defp do_prepend_data(form, key) do
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
  end

  defp do_remove_data(form, key, i) do
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
  end

  defp manage_relationship_source(%Ash.Changeset{} = changeset, config) do
    case config[:managed_relationship] do
      {source, relationship} ->
        (changeset.context[:manage_relationship_source] || []) ++
          [{source, relationship, changeset}]

      _ ->
        nil
    end
  end

  defp manage_relationship_source(form, config) do
    case config[:managed_relationship] do
      {source, relationship} when form.type != :read ->
        (form.source.context[:manage_relationship_source] || []) ++
          [{source, relationship, form.source}]

      _ ->
        nil
    end
  end

  defp set_managed_relationship_context(changeset, opts) do
    if opts[:manage_relationship_source] do
      Ash.Changeset.set_context(changeset, %{
        manage_relationship_source: opts[:manage_relationship_source]
      })
    else
      changeset
    end
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

  defp do_decode_path([], original_path, _) do
    raise "Invalid Path: #{original_path}"
  end

  defp do_decode_path(forms, original_path, [key | rest]) when is_list(forms) do
    case Integer.parse(key) do
      {index, ""} ->
        matching_form = Enum.at(forms, index)

        case matching_form do
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

  defp handle_forms(
         params,
         form_keys,
         error?,
         prev_data_trail,
         source_changeset,
         name,
         id,
         data_updates,
         trail \\ []
       ) do
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
            error?,
            source_changeset,
            name,
            id,
            data_updates
          )

        :error ->
          handle_form_without_params(
            forms,
            params,
            opts,
            key,
            trail,
            prev_data_trail,
            error?,
            source_changeset,
            name,
            id,
            data_updates
          )
      end
    end)
  end

  defp handle_form_without_params(
         forms,
         params,
         opts,
         key,
         trail,
         prev_data_trail,
         error?,
         source_changeset,
         name,
         id,
         data_updates
       ) do
    form_values =
      if Keyword.has_key?(opts, :data) do
        update_action =
          opts[:update_action] ||
            raise AshPhoenix.Form.NoActionConfigured,
              path: Enum.reverse(trail, [key]),
              action: :update

        data =
          if opts[:data] do
            if is_function(opts[:data]) do
              if Enum.at(prev_data_trail, 0) do
                case call_data(opts[:data], prev_data_trail) do
                  %Ash.NotLoaded{} ->
                    raise AshPhoenix.Form.NoDataLoaded,
                      path: Enum.reverse(trail, [key])

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
          {data, further} = apply_data_updates(data_updates, data, [key])

          if data do
            if (opts[:type] || :single) == :single do
              for_action(data, update_action,
                errors: error?,
                prev_data_trail: prev_data_trail,
                forms: opts[:forms] || [],
                manage_relationship_source: manage_relationship_source(source_changeset, opts),
                as: name <> "[#{key}]",
                id: id <> "_#{key}",
                data_updates: further
              )
            else
              data
              |> Enum.with_index()
              |> Enum.map(fn {data, index} ->
                for_action(data, update_action,
                  errors: error?,
                  prev_data_trail: prev_data_trail,
                  forms: opts[:forms] || [],
                  manage_relationship_source: manage_relationship_source(source_changeset, opts),
                  as: name <> "[#{key}][#{index}]",
                  id: id <> "_#{key}_#{index}",
                  data_updates: updates_for_index(further, index)
                )
              end)
            end
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

  defp updates_for_index(data_updates, i) do
    data_updates
    |> Enum.filter(fn
      {_, [^i | _]} ->
        true

      _ ->
        false
    end)
    |> Enum.map(fn {instruction, path} ->
      {instruction, Enum.drop(path, 1)}
    end)
  end

  defp apply_data_updates(data_updates, data, [key]) do
    relevant =
      Enum.filter(data_updates, fn
        {_instruction, [^key | _rest]} ->
          true

        _ ->
          false
      end)

    {immediately_relevant, further} =
      Enum.split_with(relevant, fn {_instruction, path} ->
        case path do
          [^key] ->
            true

          [^key, integer] when is_integer(integer) ->
            true

          _ ->
            false
        end
      end)

    further =
      Enum.map(further, fn {instruction, [^key | rest]} ->
        {instruction, rest}
      end)

    data = do_apply_updates(data, immediately_relevant)

    {data, further}
  end

  defp do_apply_updates(data, instructions) do
    instructions
    |> Enum.reverse()
    |> Enum.reduce(data, fn
      {:prepend, [_]}, data ->
        cond do
          is_function(data, 1) ->
            fn original_data ->
              do_prepend(data.(original_data))
            end

          is_function(data, 2) ->
            fn original_data, path ->
              do_prepend(data.(original_data, path))
            end

          true ->
            do_prepend(data)
        end

      {:remove, [_, i]}, data ->
        cond do
          is_function(data, 1) ->
            fn original_data ->
              do_remove(data.(original_data), i)
            end

          is_function(data, 2) ->
            fn original_data, path ->
              do_remove(do_prepend(data.(original_data, path)), i)
            end

          true ->
            do_remove(data, i)
        end

      {:remove, [_]}, _data ->
        nil
    end)
  end

  defp do_prepend(data) do
    if is_list(data) do
      [nil | data]
    else
      data
    end
  end

  defp do_remove(data, i) do
    if is_list(data) do
      List.delete_at(data, i)
    else
      data
    end
  end

  defp handle_form_with_params(
         forms,
         params,
         form_params,
         opts,
         key,
         trail,
         prev_data_trail,
         error?,
         source_changeset,
         name,
         id,
         data_updates
       ) do
    form_values =
      if Keyword.has_key?(opts, :data) do
        handle_form_with_params_and_data(
          opts,
          form_params,
          key,
          trail,
          prev_data_trail,
          error?,
          source_changeset,
          name,
          id,
          data_updates
        )
      else
        handle_form_with_params_and_no_data(
          opts,
          form_params,
          key,
          trail,
          prev_data_trail,
          error?,
          source_changeset,
          name,
          id,
          data_updates
        )
      end

    {Map.put(forms, key, form_values), Map.delete(params, [key, to_string(key)])}
  end

  defp handle_form_with_params_and_no_data(
         opts,
         form_params,
         key,
         trail,
         prev_data_trail,
         error?,
         source_changeset,
         name,
         id,
         data_updates
       ) do
    if (opts[:type] || :single) == :single do
      {_, further} = apply_data_updates(data_updates, nil, [key])

      if map(form_params)["_form_type"] == "read" do
        read_action =
          opts[:read_action] ||
            raise AshPhoenix.Form.NoActionConfigured,
              path: Enum.reverse(trail, [key]),
              action: :read

        resource =
          opts[:read_resource] || opts[:resource] ||
            raise AshPhoenix.Form.NoResourceConfigured,
              path: Enum.reverse(trail, [key])

        for_action(resource, read_action,
          params: form_params,
          forms: opts[:forms] || [],
          errors: error?,
          prev_data_trail: prev_data_trail,
          manage_relationship_source: manage_relationship_source(source_changeset, opts),
          as: name <> "[#{key}]",
          id: id <> "_#{key}",
          data_updates: further
        )
      else
        create_action =
          opts[:create_action] ||
            raise AshPhoenix.Form.NoActionConfigured,
              path: Enum.reverse(trail, [key]),
              action: :create

        resource =
          opts[:create_resource] || opts[:resource] ||
            raise AshPhoenix.Form.NoResourceConfigured,
              path: Enum.reverse(trail, [key])

        for_action(resource, create_action,
          params: form_params,
          forms: opts[:forms] || [],
          errors: error?,
          prev_data_trail: prev_data_trail,
          manage_relationship_source: manage_relationship_source(source_changeset, opts),
          as: name <> "[#{key}]",
          id: id <> "_#{key}",
          data_updates: further
        )
      end
    else
      {_, further} = apply_data_updates(data_updates, [], [key])

      form_params
      |> indexed_list()
      |> Enum.with_index()
      |> Enum.map(fn {form_params, index} ->
        if map(form_params)["_form_type"] == "read" do
          read_action =
            opts[:read_action] ||
              raise AshPhoenix.Form.NoActionConfigured,
                path: Enum.reverse(trail, [key]),
                action: :read

          resource =
            opts[:read_resource] || opts[:resource] ||
              raise AshPhoenix.Form.NoResourceConfigured,
                path: Enum.reverse(trail, [key])

          for_action(resource, read_action,
            params: form_params,
            forms: opts[:forms] || [],
            errors: error?,
            prev_data_trail: prev_data_trail,
            manage_relationship_source: manage_relationship_source(source_changeset, opts),
            as: name <> "[#{key}][#{index}]",
            id: id <> "_#{key}_#{index}",
            data_updates: updates_for_index(further, index)
          )
        else
          create_action =
            opts[:create_action] ||
              raise AshPhoenix.Form.NoActionConfigured,
                path: Enum.reverse(trail, [key]),
                action: :create

          resource =
            opts[:create_resource] || opts[:resource] ||
              raise AshPhoenix.Form.NoResourceConfigured,
                path: Enum.reverse(trail, [key])

          for_action(resource, create_action,
            params: form_params,
            forms: opts[:forms] || [],
            errors: error?,
            prev_data_trail: prev_data_trail,
            manage_relationship_source: manage_relationship_source(source_changeset, opts),
            as: name <> "[#{key}][#{index}]",
            id: id <> "_#{key}_#{index}",
            data_updates: updates_for_index(further, index)
          )
        end
      end)
    end
  end

  defp handle_form_with_params_and_data(
         opts,
         form_params,
         key,
         trail,
         prev_data_trail,
         error?,
         source_changeset,
         name,
         id,
         data_updates
       ) do
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

    {data, further} = apply_data_updates(data_updates, data, [key])

    if (opts[:type] || :single) == :single do
      if data || map(form_params)["_form_type"] == "read" do
        case map(form_params)["_form_type"] || "update" do
          "update" ->
            update_action =
              opts[:update_action] ||
                raise AshPhoenix.Form.NoActionConfigured,
                  path: Enum.reverse(trail, [key]),
                  action: :update

            for_action(data, update_action,
              params: form_params,
              forms: opts[:forms] || [],
              errors: error?,
              prev_data_trail: prev_data_trail,
              manage_relationship_source: manage_relationship_source(source_changeset, opts),
              as: name <> "[#{key}]",
              id: id <> "_#{key}",
              data_updates: further
            )

          "destroy" ->
            destroy_action =
              opts[:destroy_action] ||
                raise AshPhoenix.Form.NoActionConfigured,
                  path: Enum.reverse(trail, [key]),
                  action: :destroy

            for_action(data, destroy_action,
              params: form_params,
              forms: opts[:forms] || [],
              errors: error?,
              prev_data_trail: prev_data_trail,
              manage_relationship_source: manage_relationship_source(source_changeset, opts),
              as: name <> "[#{key}]",
              id: id <> "_#{key}",
              data_updates: further
            )
        end
      else
        case map(form_params)["_form_type"] || "create" do
          "create" ->
            create_action =
              opts[:create_action] ||
                raise AshPhoenix.Form.NoActionConfigured,
                  path: Enum.reverse(trail, [key]),
                  action: :create

            resource =
              opts[:create_resource] || opts[:resource] ||
                raise AshPhoenix.Form.NoResourceConfigured,
                  path: Enum.reverse(trail, [key])

            for_action(resource, create_action,
              params: form_params,
              forms: opts[:forms] || [],
              errors: error?,
              prev_data_trail: prev_data_trail,
              manage_relationship_source: manage_relationship_source(source_changeset, opts),
              as: name <> "[#{key}]",
              id: id <> "_#{key}",
              data_updates: further
            )

          "read" ->
            resource =
              opts[:read_resource] || opts[:resource] ||
                raise AshPhoenix.Form.NoResourceConfigured,
                  path: Enum.reverse(trail, [key])

            read_action =
              opts[:read_action] ||
                raise AshPhoenix.Form.NoActionConfigured,
                  path: Enum.reverse(trail, [key]),
                  action: :read

            for_action(resource, read_action,
              params: form_params,
              forms: opts[:forms] || [],
              errors: error?,
              prev_data_trail: prev_data_trail,
              manage_relationship_source: manage_relationship_source(source_changeset, opts),
              as: name <> "[#{key}]",
              id: id <> "_#{key}",
              data_updates: further
            )
        end
      end
    else
      data = List.wrap(data)

      form_params
      |> indexed_list()
      |> Enum.with_index()
      |> Enum.reduce({[], List.wrap(data)}, fn {form_params, index}, {forms, data} ->
        if map(form_params)["_form_type"] == "read" do
          resource =
            opts[:read_resource] || opts[:resource] ||
              raise AshPhoenix.Form.NoResourceConfigured,
                path: Enum.reverse(trail, [key])

          read_action =
            opts[:read_action] ||
              raise AshPhoenix.Form.NoActionConfigured,
                path: Enum.reverse(trail, [key]),
                action: :read

          form =
            for_action(resource, read_action,
              params: form_params,
              forms: opts[:forms] || [],
              errors: error?,
              prev_data_trail: prev_data_trail,
              manage_relationship_source: manage_relationship_source(source_changeset, opts),
              as: name <> "[#{key}][#{index}]",
              id: id <> "_#{key}_#{index}",
              data_updates: updates_for_index(further, index)
            )

          {[form | forms], data}
        else
          case data do
            [nil | rest] ->
              create_action =
                opts[:create_action] ||
                  raise AshPhoenix.Form.NoActionConfigured,
                    path: Enum.reverse(trail, [key]),
                    action: :create

              resource =
                opts[:create_resource] || opts[:resource] ||
                  raise AshPhoenix.Form.NoResourceConfigured,
                    path: Enum.reverse(trail, [key])

              form =
                for_action(resource, create_action,
                  params: form_params,
                  forms: opts[:forms] || [],
                  errors: error?,
                  prev_data_trail: prev_data_trail,
                  manage_relationship_source: manage_relationship_source(source_changeset, opts),
                  as: name <> "[#{key}][#{index}]",
                  id: id <> "_#{key}_#{index}",
                  data_updates: updates_for_index(further, index)
                )

              {[form | forms], rest}

            [data | rest] ->
              form =
                if map(form_params)["_form_type"] == "destroy" do
                  destroy_action =
                    opts[:destroy_action] ||
                      raise AshPhoenix.Form.NoActionConfigured,
                        path: Enum.reverse(trail, [key]),
                        action: :destroy

                  for_action(data, destroy_action,
                    params: form_params,
                    forms: opts[:forms] || [],
                    errors: error?,
                    prev_data_trail: prev_data_trail,
                    manage_relationship_source:
                      manage_relationship_source(source_changeset, opts),
                    as: name <> "[#{key}][#{index}]",
                    id: id <> "_#{key}_#{index}",
                    data_updates: updates_for_index(further, index)
                  )
                else
                  update_action =
                    opts[:update_action] ||
                      raise AshPhoenix.Form.NoActionConfigured,
                        path: Enum.reverse(trail, [key]),
                        action: :update

                  for_action(data, update_action,
                    params: form_params,
                    forms: opts[:forms] || [],
                    errors: error?,
                    prev_data_trail: prev_data_trail,
                    manage_relationship_source:
                      manage_relationship_source(source_changeset, opts),
                    as: name <> "[#{key}][#{index}]",
                    id: id <> "_#{key}_#{index}",
                    data_updates: updates_for_index(further, index)
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
                    path: Enum.reverse(trail, [key]),
                    action: :create

              form =
                for_action(resource, create_action,
                  params: form_params,
                  forms: opts[:forms] || [],
                  errors: error?,
                  prev_data_trail: prev_data_trail,
                  manage_relationship_source: manage_relationship_source(source_changeset, opts),
                  as: name <> "[#{key}][#{index}]",
                  id: id <> "_#{key}_#{index}",
                  data_updates: updates_for_index(further, index)
                )

              {[form | forms], []}
          end
        end
      end)
      |> elem(0)
      |> Enum.reverse()
    end
  end

  defp map(map) when is_map(map), do: map
  defp map(_), do: %{}

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
    |> Enum.map(fn key ->
      map[to_string(key)]
    end)
  end

  defp indexed_list(other) do
    List.wrap(other)
  end

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

      hidden =
        case form.touched_forms |> Enum.join(",") do
          "" -> hidden
          fields -> Keyword.put(hidden, :_touched, fields)
        end

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
            to_form(form.forms[field], opts)
          end

        :list ->
          form.forms[field]
          |> Kernel.||([])
          |> Enum.map(&to_form(&1, opts))
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
           :error <- get_non_attribute_non_argument_param(changeset, field),
           :error <- Map.fetch(changeset.data, field) do
        nil
      else
        {:ok, %Ash.NotLoaded{}} ->
          nil

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

    defp get_non_attribute_non_argument_param(changeset, field) do
      if Ash.Resource.Info.attribute(changeset.resource, field) ||
           Enum.any?(changeset.action.arguments, &(&1.name == field)) do
        :error
      else
        Map.fetch(changeset.params, Atom.to_string(field))
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
      Map.fetch(changeset.attributes, field)
    end
  end
end
