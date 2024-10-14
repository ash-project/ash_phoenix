defmodule AshPhoenix.Form do
  @moduledoc """
  A module to allow you to fluidly use resources with Phoenix forms.

  ### Life cycle

  The general workflow is, with either LiveView or Phoenix forms:

  1. Create a form with `AshPhoenix.Form`
  2. Render the form with `Phoenix.Component.form` (or `CoreComponents.simple_form`), or, if using Surface, `<Form>`
  3. To validate the form (e.g with `phx-change` for liveview), pass the submitted params to `AshPhoenix.Form.validate/3`
  4. On form submission, pass the params to `AshPhoenix.Form.submit/2`
  5. On success, use the result to redirect or assign. On failure, reassign the provided form.

  The following keys exist on the form to show where in the lifecycle you are:

  - `submitted_once?` - If the form has ever been submitted. Useful for not showing any errors on the first attempt to fill out a form.
  - `just_submitted?` - If the form has just been submitted and *no validation* has happened since. Useful for things like
    triggering a UI effect that should stop when the form is modified again.
  - `.changed?` - If something about the form is different than it originally was. Note that in some cases this can yield a
    false positive, specifically if a nested form is removed and then a new one is added with the exact same values.
  - `.touched_forms` - A MapSet containing all keys in the form that have been modified. When submitting a form, only these keys are included in the parameters.

  ### Working with related data

  If your resource action accepts related data, (for example a managed relationship argument, or an embedded resource attribute), you can
  use Phoenix's `inputs_for` for that field, *but* you must do one of two things:

  1. Tell AshPhoenix.Form to automatically derive this behavior from your action, for example:

  ```elixir
  form =
    user
    |> AshPhoenix.Form.for_update(:update, forms: [auto?: true])
    |> to_form()
  ```

  2. Explicitly configure the behavior of it using the `forms` option. See `for_create/3` for more.

  For example:

  ```elixir
  form =
    user
    |> AshPhoenix.Form.for_update(:update,
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
    |> to_form()
  ```

  ## LiveView
  `AshPhoenix.Form` (unlike ecto changeset based forms) expects to be reused throughout the lifecycle of the liveview.

  You can use Phoenix events to add and remove form entries and `submit/2` to submit the form, like so:

  ```elixir
  def render(assigns) do
    ~H\"\"\"
    <.simple_form for={@form} phx-change="validate" phx-submit="submit">
      <%!-- Attributes for the parent resource --%>
      <.input type="email" label="Email" field={@form[:email]} />
      <%!-- Render nested forms for related data --%>
      <.inputs_for :let={item_form} field={@form[:items]}>
        <.input type="text" label="Item" field={item_form[:name]} />
        <.input type="number" label="Amount" field={item_form[:amount]} />
        <.button type="button" phx-click="remove_form" phx-value-path={item_form.name}>
          Remove
        </.button>
      </.inputs_for>
      <:actions>
        <.button type="button" phx-click="add_form" phx-value-path={@form[:items].name}>
          Add Item
        </.button>
        <.button>Save</.button>
      </:actions>
    </.simple_form>
    \"\"\"
  end

  def mount(_params, _session, socket) do
    form =
      MyApp.Grocery.Order
      |> AshPhoenix.Form.for_create(:create,
        forms: [
          items: [
            type: :list,
            resource: MyApp.Grocery.Item,
            create_action: :create
          ]
        ]
      )
      |> AshPhoenix.Form.add_form([:items])
      |> to_form()

    {:ok, assign(socket, form: form)}
  end

  # In order to use the `add_form` and `remove_form` helpers, you
  # need to make sure that you are validating the form on change
  def handle_event("validate", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.form, params)
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("submit", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, order} ->
        {:noreply,
         socket
         |> put_flash(:info, "Saved order for \#{order.email}!")
         |> push_navigate(to: ~p"/")}

      {:error, form} ->
        {:noreply, assign(socket, form: form)}
    end
  end

  def handle_event("add_form", %{"path" => path}, socket) do
    form = AshPhoenix.Form.add_form(socket.assigns.form, path)
    {:noreply, assign(socket, form: form)}
  end

  def handle_event("remove_form", %{"path" => path}, socket) do
    form = AshPhoenix.Form.remove_form(socket.assigns.form, path)
    {:noreply, assign(socket, form: form)}
  end
  ```
  """

  @derive {Inspect, except: [:opts]}
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
    :domain,
    :method,
    :submit_errors,
    :opts,
    :id,
    :transform_errors,
    :original_data,
    :transform_params,
    :prepare_params,
    :prepare_source,
    warn_on_unhandled_errors?: true,
    any_removed?: false,
    added?: false,
    changed?: false,
    touched_forms: MapSet.new(),
    valid?: false,
    errors: false,
    submitted_once?: false,
    just_submitted?: false
  ]

  alias AshPhoenix.Form.InvalidPath

  @type source :: Ash.Changeset.t() | Ash.Query.t() | Ash.Resource.record()

  @type t :: %__MODULE__{
          resource: Ash.Resource.t(),
          action: atom,
          type: :create | :update | :destroy | :read,
          params: map,
          source: source,
          transform_params: nil | (map -> term),
          data: nil | Ash.Resource.record(),
          form_keys: Keyword.t(),
          forms: map,
          method: String.t(),
          submit_errors: Keyword.t() | nil,
          prepare_source: nil | (source -> source),
          opts: Keyword.t(),
          transform_errors:
            nil
            | (source, error :: Ash.Error.t() ->
                 [{field :: atom, message :: String.t(), substituations :: Keyword.t()}]),
          valid?: boolean,
          errors: boolean,
          submitted_once?: boolean,
          just_submitted?: boolean
        }

  @type path :: String.t() | atom | list(String.t() | atom | integer)

  @for_opts [
    actor: [
      type: :any,
      doc: "The actor performing the action. Passed through to the underlying action."
    ],
    forms: [
      type: :keyword_list,
      doc: "Nested form configurations. See `for_create/3` \"Nested Form Options\" docs for more."
    ],
    warn_on_unhandled_errors?: [
      type: :boolean,
      default: true,
      doc: """
      Warns on any errors that don't match the form pattern of `{:field, "message", [replacement: :vars]}` or implement the `AshPhoenix.FormData.Error` protocol.
      """
    ],
    domain: [
      type: :atom,
      doc: "The domain to use when calling the action."
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
    prepare_source: [
      type: {:or, [{:fun, 1}, {:in, [nil]}]},
      doc: """
      A 1-argument function the receives the initial changeset (or query) and makes any relevant changes to it.
      This can be used to do things like:

      * Set default argument values before the validations are run using `Ash.Changeset.set_arguments/2` or `Ash.Changeset.set_argument/3`
      * Set changeset context
      * Do any other pre-processing on the changeset
      """
    ],
    prepare_params: [
      type: {:or, [{:fun, 2}, {:in, [nil]}]},
      doc: """
      A 2-argument function that receives the params map and the :validate atom and should return prepared params.
      Called before the form is validated.
      """
    ],
    transform_params: [
      type: {:or, [{:fun, 2}, {:fun, 3}, {:in, [nil]}]},
      doc: """
      A function for post-processing the form parameters before they are used for changeset validation/submission.
      Use a 3-argument function to pattern match on the `AshPhoenix.Form` struct.
      """
    ],
    method: [
      type: :string,
      doc:
        "The http method to associate with the form. Defaults to `post` for creates, and `put` for everything else."
    ],
    exclude_fields_if_empty: [
      type: {:list, {:or, [:atom, :string, {:tuple, [:any, :any]}]}},
      doc: """
      These fields will be ignored if they are empty strings.

      This list of fields supports dead view forms. When a form is submitted from dead view
      empty fields are submitted as empty strings. This is problematic for fields that allow_nil
      or those that have default values.
      """
    ],
    tenant: [
      type: :any,
      doc: "The current tenant. Passed through to the underlying action."
    ]
  ]

  @nested_form_opts [
    type: [
      type: {:one_of, [:list, :single]},
      default: :single,
      doc: "The cardinality of the nested form - `:list` or `:single`."
    ],
    sparse?: [
      type: :boolean,
      doc: """
      If the nested form is `sparse`, the form won't expect all inputs for all forms to be present.

      Has no effect if the type is `:single`.

      Normally, if you leave some forms out of a list of nested forms, they are removed from the parameters
      passed to the action. For example, if you had a `post` with two comments `[%Comment{id: 1}, %Comment{id: 2}]`
      and you passed down params like `comments[0][id]=1&comments[1][text]=new_text`, we would remove the second comment
      from the input parameters, resulting in the following being passed into the action: `%{"comments" => [%{"id" => 1, "text" => "new"}]}`.
      By setting it to sparse, you have to explicitly use `remove_form` for that removal to happen. So in the same scenario above, the parameters
      that would be sent would actually be `%{"comments" => [%{"id" => 1, "text" => "new"}, %{"id" => 2}]}`.

      One major difference with `sparse?` is that the form actually ignores the *index* provided, e.g `comments[0]...`, and instead uses the primary
      key e.g `comments[0][id]` to match which form is being updated. This prevents you from having to find the index of the specific item you want to
      update. Which could be very gnarly on deeply nested forms. If there is no primary key, or the primary key does not match anything, it is treated
      as a new form.

      REMEMBER: You need to use `Phoenix.Components.inputs_for` to render the nested forms, or manually add hidden inputs using
      `hidden_inputs_for` (or `HiddenInputs` if using Surface) for the id to be automatically placed into the form.
      """
    ],
    forms: [
      type: :keyword_list,
      doc: "Forms nested inside the current nesting level in all cases."
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

  defp validate_opts_with_extra_keys(opts, schema) do
    keys = Keyword.keys(schema)

    {opts, extra} = Keyword.split(opts, keys)

    opts = Spark.Options.validate!(opts, schema)

    Keyword.merge(opts, extra)
  end

  import AshPhoenix.FormData.Helpers

  @doc """
  Creates a form corresponding to any given action on a resource.

  If given a create, read, update, or destroy action, the appropriate `for_*`
  function will be called instead. So use this function when you don't know
  the type of the action, or it is a generic action.

  Options:
  #{Spark.Options.docs(@for_opts)}

  Any *additional* options will be passed to the underlying call to build the source, i.e
  `Ash.ActionInput.for_action/4`, or `Ash.Changeset.for_*`. This means you can set things
  like the tenant/actor. These will be retained, and provided again when `Form.submit/3` is called.

  ## Nested Form Options

  #{Spark.Options.docs(@nested_form_opts)}
  """
  def for_action(resource_or_data, action, opts \\ []) do
    {resource, data} =
      case resource_or_data do
        module when is_atom(resource_or_data) and not is_nil(resource_or_data) ->
          {module, module.__struct__()}

        %resource{} = data ->
          if Ash.Resource.Info.resource?(resource) do
            {resource, data}
          else
            {AshPhoenix.Form.WrappedValue, %AshPhoenix.Form.WrappedValue{value: data}}
          end

        value ->
          {AshPhoenix.Form.WrappedValue, %AshPhoenix.Form.WrappedValue{value: value}}
      end

    opts = update_opts(opts, data, opts[:params] || %{})

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

      :action ->
        do_for_action(resource, action, opts)
    end
  end

  defp do_for_action(resource, action, opts) do
    opts =
      opts
      |> add_auto(resource, action)
      |> update_opts(opts[:data], opts[:params] || %{})
      |> validate_opts_with_extra_keys(@for_opts)
      |> forms_for_type(:action)

    require_action!(resource, action, :action)

    name = opts[:as] || "form"
    id = opts[:id] || opts[:as] || "form"

    {forms, params} =
      handle_forms(
        opts[:params] || %{},
        opts[:forms] || [],
        !!opts[:errors],
        opts[:domain] || Ash.Resource.Info.domain(resource),
        opts[:actor],
        opts[:tenant],
        [],
        name,
        id,
        opts[:transform_errors],
        opts[:warn_on_unhandled_errors?]
      )

    prepare_source = opts[:prepare_source] || (& &1)

    query_opts =
      drop_form_opts(opts)

    source =
      resource
      |> Ash.ActionInput.new()
      |> prepare_source.()
      |> set_accessing_from(opts)

    source =
      Ash.ActionInput.for_action(
        source,
        action,
        params || %{},
        allow_all_keys_to_be_skipped(query_opts, params)
      )
      |> add_errors_for_unhandled_params(params)

    %__MODULE__{
      resource: resource,
      action: action,
      type: :action,
      data: opts[:data],
      params: params,
      errors: opts[:errors],
      transform_errors: opts[:transform_errors],
      warn_on_unhandled_errors?: opts[:warn_on_unhandled_errors?],
      name: name,
      forms: forms,
      form_keys: Keyword.new(List.wrap(opts[:forms])),
      id: id,
      domain: source.domain,
      method: opts[:method] || form_for_method(:create),
      opts: opts,
      touched_forms: touched_forms(forms, params, opts),
      transform_params: opts[:transform_params],
      prepare_params: opts[:prepare_params],
      prepare_source: opts[:prepare_source],
      source: source
    }
    |> set_changed?()
    |> set_validity()
    |> carry_over_errors()
  end

  @doc """
  Creates a form corresponding to a create action on a resource.


  ## Options

  Options not listed below are passed to the underlying call to build the changeset/query, i.e `Ash.Changeset.for_create/4`

  #{Spark.Options.docs(@for_opts)}

  ## Nested Form Options

  To automatically determine the nested forms available for a given form, use `forms: [auto?: true]`.
  You can add additional nested forms by including them in the `forms` config alongside `auto?: true`.
  See the module documentation of `AshPhoenix.Form.Auto` for more information. If you want to do some
  manipulation of the auto forms, you can also call `AshPhoenix.Form.Auto.auto/2`, and then manipulate the
  result and pass it to the `forms` option. To pass options, use `auto?: [option1: :value]`. See the
  documentation of `AshPhoenix.Form.Auto` for more.

  #{Spark.Options.docs(@nested_form_opts)}
  """
  @spec for_create(Ash.Resource.t(), action :: atom, opts :: Keyword.t()) :: t()
  def for_create(resource, action, opts \\ []) when is_atom(resource) do
    opts =
      opts
      |> add_auto(resource, action)
      |> update_opts(nil, opts[:params] || %{})
      |> validate_opts_with_extra_keys(@for_opts)
      |> forms_for_type(:create)

    require_action!(resource, action, :create)

    changeset_opts = drop_form_opts(opts)

    name = opts[:as] || "form"
    id = opts[:id] || opts[:as] || "form"

    {forms, params} =
      handle_forms(
        opts[:params] || %{},
        opts[:forms] || [],
        !!opts[:errors],
        opts[:domain] || Ash.Resource.Info.domain(resource),
        opts[:actor],
        opts[:tenant],
        [],
        name,
        id,
        opts[:transform_errors],
        opts[:warn_on_unhandled_errors?]
      )

    prepare_source = opts[:prepare_source] || (& &1)

    source =
      resource
      |> Ash.Changeset.new()
      |> prepare_source.()
      |> set_accessing_from(opts)

    source =
      Ash.Changeset.for_create(
        source,
        action,
        params,
        allow_all_keys_to_be_skipped(changeset_opts, params)
      )

    %__MODULE__{
      resource: resource,
      action: action,
      type: :create,
      domain: source.domain,
      params: params,
      errors: opts[:errors],
      transform_errors: opts[:transform_errors],
      warn_on_unhandled_errors?: opts[:warn_on_unhandled_errors?],
      name: name,
      forms: forms,
      form_keys: Keyword.new(List.wrap(opts[:forms])),
      id: id,
      touched_forms: touched_forms(forms, params, opts),
      method: opts[:method] || form_for_method(:create),
      transform_params: opts[:transform_params],
      prepare_params: opts[:prepare_params],
      prepare_source: opts[:prepare_source],
      opts: opts,
      source: source
    }
    |> set_changed?()
    |> set_validity()
    |> carry_over_errors()
  end

  @doc """
  Creates a form corresponding to an update action on a record.

  Options:
  #{Spark.Options.docs(@for_opts)}

  Any *additional* options will be passed to the underlying call to `Ash.Changeset.for_update/4`. This means
  you can set things like the tenant/actor. These will be retained, and provided again when `Form.submit/3` is called.
  """
  @spec for_update(Ash.Resource.record(), action :: atom, opts :: Keyword.t()) :: t()
  def for_update(%resource{} = data, action, opts \\ []) do
    opts =
      opts
      |> add_auto(resource, action)
      |> update_opts(data, opts[:params] || %{})
      |> validate_opts_with_extra_keys(@for_opts)
      |> forms_for_type(:update)

    require_action!(resource, action, :update)

    changeset_opts = drop_form_opts(opts)

    name = opts[:as] || "form"
    id = opts[:id] || opts[:as] || "form"

    prepare_source = opts[:prepare_source] || (& &1)

    {forms, params} =
      handle_forms(
        opts[:params] || %{},
        opts[:forms] || [],
        !!opts[:errors],
        opts[:domain] || Ash.Resource.Info.domain(resource),
        opts[:actor],
        opts[:tenant],
        [
          data | opts[:prev_data_trail] || []
        ],
        name,
        id,
        opts[:transform_errors],
        opts[:warn_on_unhandled_errors?],
        [data]
      )

    source =
      data
      |> Ash.Changeset.new()
      |> prepare_source.()
      |> set_accessing_from(opts)

    source =
      Ash.Changeset.for_update(
        source,
        action,
        params,
        allow_all_keys_to_be_skipped(changeset_opts, params)
      )

    %__MODULE__{
      resource: resource,
      data: data,
      action: action,
      type: :update,
      domain: source.domain,
      params: params,
      errors: opts[:errors],
      transform_errors: opts[:transform_errors],
      warn_on_unhandled_errors?: opts[:warn_on_unhandled_errors?],
      forms: forms,
      form_keys: Keyword.new(List.wrap(opts[:forms])),
      original_data: data,
      method: opts[:method] || form_for_method(:update),
      touched_forms: touched_forms(forms, params, opts),
      transform_params: opts[:transform_params],
      prepare_params: opts[:prepare_params],
      prepare_source: opts[:prepare_source],
      opts: opts,
      id: id,
      name: name,
      source: source
    }
    |> set_changed?()
    |> set_validity()
    |> carry_over_errors()
  end

  @spec can_submit?(t()) :: boolean()
  @spec can_submit?(Phoenix.HTML.Form.t()) :: boolean

  def can_submit?(%Phoenix.HTML.Form{} = form) do
    can_submit?(form.source)
  end

  def can_submit?(form) do
    Ash.can?(form.source, form.source.context[:private][:actor], tenant: form.source.tenant)
  end

  @spec ensure_can_submit!(t()) :: t()
  @spec ensure_can_submit!(Phoenix.HTML.Form.t()) :: Phoenix.HTML.Form.t()
  def ensure_can_submit!(%Phoenix.HTML.Form{} = form) do
    %{form | source: ensure_can_submit!(form.source)}
  end

  def ensure_can_submit!(form) do
    case Ash.can(form.source, form.source.context[:private][:actor],
           return_forbidden_error?: true,
           tenant: form.source.tenant
         ) do
      {:ok, false, %{stacktrace: %{stacktrace: stacktrace}} = exception} ->
        reraise exception, stacktrace

      {:error, %{stacktrace: %{stacktrace: stacktrace}} = exception} ->
        reraise exception, stacktrace

      {:ok, false, exception} ->
        raise exception

      {:error, exception} ->
        raise exception

      {:ok, true} ->
        form
    end
  end

  @doc """
  Creates a form corresponding to a destroy action on a record.

  Options:
  #{Spark.Options.docs(@for_opts)}

  Any *additional* options will be passed to the underlying call to `Ash.Changeset.for_destroy/4`. This means
  you can set things like the tenant/actor. These will be retained, and provided again when `Form.submit/3` is called.
  """
  @spec for_destroy(Ash.Resource.record(), action :: atom, opts :: Keyword.t()) :: t()
  def for_destroy(%resource{} = data, action, opts \\ []) do
    opts =
      opts
      |> add_auto(resource, action)
      |> update_opts(data, opts[:params] || %{})
      |> validate_opts_with_extra_keys(@for_opts)
      |> forms_for_type(:destroy)

    require_action!(resource, action, :destroy)

    changeset_opts =
      drop_form_opts(opts)

    name = opts[:as] || "form"
    id = opts[:id] || opts[:as] || "form"
    prepare_source = opts[:prepare_source] || (& &1)

    {forms, params} =
      handle_forms(
        opts[:params] || %{},
        opts[:forms] || [],
        !!opts[:errors],
        opts[:domain] || Ash.Resource.Info.domain(resource),
        opts[:actor],
        opts[:tenant],
        [
          data | opts[:prev_data_trail] || []
        ],
        name,
        id,
        opts[:transform_errors],
        opts[:warn_on_unhandled_errors?],
        [data]
      )

    source =
      data
      |> Ash.Changeset.new()
      |> prepare_source.()
      |> set_accessing_from(opts)

    source =
      Ash.Changeset.for_destroy(
        source,
        action,
        params,
        allow_all_keys_to_be_skipped(changeset_opts, params)
      )

    %__MODULE__{
      resource: resource,
      data: data,
      action: action,
      type: :destroy,
      params: params,
      errors: opts[:errors],
      transform_errors: opts[:transform_errors],
      warn_on_unhandled_errors?: opts[:warn_on_unhandled_errors?],
      original_data: data,
      forms: forms,
      name: name,
      id: id,
      transform_params: opts[:transform_params],
      prepare_params: opts[:prepare_params],
      prepare_source: opts[:prepare_source],
      domain: source.domain,
      method: opts[:method] || form_for_method(:destroy),
      touched_forms: touched_forms(forms, params, opts),
      form_keys: Keyword.new(List.wrap(opts[:forms])),
      opts: opts,
      source: source
    }
    |> set_changed?()
    |> set_validity()
    |> carry_over_errors()
  end

  @doc """
  Creates a form corresponding to a read action on a resource.

  Options:
  #{Spark.Options.docs(@for_opts)}

  Any *additional* options will be passed to the underlying call to `Ash.Query.for_read/4`. This means
  you can set things like the tenant/actor. These will be retained, and provided again when `Form.submit/3` is called.

  Keep in mind that the `source` of the form in this case is a query, not a changeset. This means that, very likely,
  you would not want to use nested forms here. However, it could make sense if you had a query argument that was an
  embedded resource, so the capability remains.

  ## Nested Form Options

  #{Spark.Options.docs(@nested_form_opts)}
  """
  @spec for_read(Ash.Resource.t(), action :: atom, opts :: Keyword.t()) :: t()
  def for_read(resource, action, opts \\ []) when is_atom(resource) do
    opts =
      opts
      |> add_auto(resource, action)
      |> update_opts(opts[:data], opts[:params] || %{})
      |> validate_opts_with_extra_keys(@for_opts)
      |> forms_for_type(:read)

    require_action!(resource, action, :read)

    name = opts[:as] || "form"
    id = opts[:id] || opts[:as] || "form"

    {forms, params} =
      handle_forms(
        opts[:params] || %{},
        opts[:forms] || [],
        !!opts[:errors],
        opts[:domain] || Ash.Resource.Info.domain(resource),
        opts[:actor],
        opts[:tenant],
        [],
        name,
        id,
        opts[:transform_errors],
        opts[:warn_on_unhandled_errors?]
      )

    prepare_source = opts[:prepare_source] || (& &1)

    query_opts =
      drop_form_opts(opts)

    source =
      resource
      |> Ash.Query.new()
      |> prepare_source.()
      |> set_accessing_from(opts)

    source =
      Ash.Query.for_read(
        source,
        action,
        params || %{},
        allow_all_keys_to_be_skipped(query_opts, params)
      )
      |> add_errors_for_unhandled_params(params)

    %__MODULE__{
      resource: resource,
      action: action,
      type: :read,
      data: opts[:data],
      params: params,
      errors: opts[:errors],
      transform_errors: opts[:transform_errors],
      warn_on_unhandled_errors?: opts[:warn_on_unhandled_errors?],
      name: name,
      forms: forms,
      form_keys: Keyword.new(List.wrap(opts[:forms])),
      id: id,
      domain: source.domain,
      method: opts[:method] || form_for_method(:create),
      opts: opts,
      touched_forms: touched_forms(forms, params, opts),
      transform_params: opts[:transform_params],
      prepare_params: opts[:prepare_params],
      prepare_source: opts[:prepare_source],
      source: source
    }
    |> set_changed?()
    |> set_validity()
    |> carry_over_errors()
  end

  defp require_action!(resource, action, type) do
    case Ash.Resource.Info.action(resource, action) do
      nil ->
        raise ArgumentError, "No such action #{inspect(action)} for resource #{inspect(resource)}"

      %{type: ^type} ->
        :ok

      %{type: actual_type} ->
        raise ArgumentError,
              "Expected action of type #{inspect(type)}, but #{inspect(action)} is of type #{inspect(actual_type)}"
    end
  end

  defp set_accessing_from(changeset_or_query, opts) do
    case opts[:accessing_from] do
      {source, name} ->
        set_context(changeset_or_query, %{
          accessing_from: %{source: source, name: name}
        })

      _ ->
        changeset_or_query
    end
  end

  defp set_context(%Ash.Changeset{} = changeset, context) do
    Ash.Changeset.set_context(changeset, context)
  end

  defp set_context(%Ash.Query{} = query, context) do
    Ash.Query.set_context(query, context)
  end

  defp set_context(%Ash.ActionInput{} = query, context) do
    Ash.ActionInput.set_context(query, context)
  end

  defp add_errors_for_unhandled_params(%{action: nil} = query, _params), do: query

  defp add_errors_for_unhandled_params(query, params) do
    arguments = Enum.map(query.action.arguments, &to_string(&1.name))

    remaining_params = Map.drop(params, arguments)

    Enum.reduce(remaining_params, query, fn {key, value}, query ->
      attribute = Ash.Resource.Info.public_attribute(query.resource, key)

      if attribute do
        constraints = Ash.Type.include_source(attribute.type, query, attribute.constraints)

        case Ash.Type.cast_input(attribute.type, value, constraints) do
          {:ok, casted} ->
            %{query | params: Map.put(query.params, key, casted)}

          {:error, error} ->
            messages =
              if Keyword.keyword?(error) do
                [error]
              else
                List.wrap(error)
              end

            messages
            |> Enum.reduce(query, fn message, query ->
              message
              |> Ash.Type.Helpers.error_to_exception_opts(attribute)
              |> Enum.reduce(query, fn opts, query ->
                Ash.Query.add_error(query, Ash.Error.Changes.InvalidAttribute.exception(opts))
              end)
            end)
        end
      else
        query
      end
    end)
  end

  @doc "A utility to get the list of attributes the action underlying the form accepts"
  def attributes(form) do
    form = to_form!(form)
    AshPhoenix.Form.Auto.accepted_attributes(form.resource, form.source.action)
  end

  @doc "A utility to get the list of arguments the action underlying the form accepts"
  def arguments(form) do
    form = to_form!(form)

    action =
      case form.source.action do
        action when is_atom(action) ->
          Ash.Resource.Info.action(form.resource, action)

        action ->
          action
      end

    Enum.reject(action.arguments, &(!&1.public?))
  end

  @validate_opts [
    errors: [
      type: :boolean,
      default: true,
      doc: "Set to false to hide errors after validation."
    ],
    target: [
      type: {:list, :string},
      doc: "The `_target` param provided by phoenix. Used to support the `only_touched?` option."
    ],
    only_touched?: [
      type: :boolean,
      default: false,
      doc: """
      If set to true, only fields that have been marked as touched will be used

      If you use this for validation you likely want to use it when submitting as well.
      """
    ]
  ]

  @doc """
  Validates the parameters against the form.

  Options:

  #{Spark.Options.docs(@validate_opts)}
  """
  @spec validate(t(), map, Keyword.t()) :: t()
  @spec validate(Phoenix.HTML.Form.t(), map, Keyword.t()) :: Phoenix.HTML.Form.t()
  def validate(form, new_params, opts \\ [])

  def validate(%Phoenix.HTML.Form{} = form, new_params, opts) do
    form.source
    |> validate(new_params, opts)
    |> Phoenix.HTML.FormData.to_form(form.options)
  end

  def validate(%{name: name} = form, new_params, opts) do
    form = Map.update!(form, :opts, &update_opts(&1, form.data, new_params))

    form = %{
      form
      | transform_params: opts[:transform_params] || form.opts[:transform_params],
        prepare_params: opts[:prepare_params] || form.opts[:prepare_params],
        prepare_source: opts[:prepare_source] || form.opts[:prepare_source],
        transform_errors: opts[:transform_errors] || form.opts[:transform_errors],
        warn_on_unhandled_errors?:
          opts[:warn_on_unhandled_errors] || form.opts[:warn_on_unhandled_errors?]
    }

    form =
      case opts[:target] do
        [^name | target] ->
          field = List.last(target)
          path = :lists.droplast(target)

          case path do
            [] ->
              touch(form, field)

            path ->
              path =
                Enum.map(path, fn item ->
                  cond do
                    is_integer(item) ->
                      item

                    is_binary(item) ->
                      String.to_existing_atom(item)

                    true ->
                      item
                  end
                end)

              update_form(form, path, &touch(&1, field))
          end

        _ ->
          form
      end

    new_params =
      if opts[:only_touched?] do
        Map.take(new_params, Enum.to_list(form.touched_forms))
      else
        new_params
      end

    opts = validate_opts_with_extra_keys(opts, @validate_opts)

    prepare_source = form.prepare_source || (& &1)

    new_params =
      if form.prepare_params do
        form.prepare_params.(new_params, :validate)
      else
        new_params
      end

    matcher =
      opts[:matcher] ||
        fn nested_form, _params, root_form, key, index ->
          nested_form.id == root_form.id <> "_#{key}_#{index}"
        end

    source_opts = drop_form_opts(form.opts)

    {forms, changeset_params} =
      validate_nested_forms(
        form,
        new_params || %{},
        !!opts[:errors],
        (opts[:prev_data_trail] || []) ++ [form.data],
        matcher
      )

    changeset_params =
      if form.transform_params do
        if is_function(form.transform_params, 2) do
          form.transform_params.(changeset_params, :validate)
        else
          form.transform_params.(form, changeset_params, :validate)
        end
      else
        changeset_params
      end

    new_source =
      case form.type do
        :create ->
          form.resource
          |> Ash.Changeset.new()
          |> prepare_source.()
          |> set_accessing_from(
            accessing_from: opts[:accessing_from] || form.opts[:accessing_from]
          )
          |> Ash.Changeset.for_create(
            form.action,
            Map.drop(changeset_params, ["_form_type", "_touched", "_union_type"]),
            allow_all_keys_to_be_skipped(source_opts, changeset_params)
          )

        :update ->
          form.data
          |> Ash.Changeset.new()
          |> prepare_source.()
          |> set_accessing_from(
            accessing_from: opts[:accessing_from] || form.opts[:accessing_from]
          )
          |> Ash.Changeset.for_update(
            form.action,
            Map.drop(changeset_params, ["_form_type", "_touched", "_union_type"]),
            allow_all_keys_to_be_skipped(source_opts, changeset_params)
          )

        :destroy ->
          form.data
          |> Ash.Changeset.new()
          |> prepare_source.()
          |> set_accessing_from(
            accessing_from: opts[:accessing_from] || form.opts[:accessing_from]
          )
          |> Ash.Changeset.for_destroy(
            form.action,
            Map.drop(changeset_params, ["_form_type", "_touched", "_union_type"]),
            allow_all_keys_to_be_skipped(source_opts, changeset_params)
          )

        :read ->
          form.resource
          |> Ash.Query.new()
          |> prepare_source.()
          |> set_accessing_from(
            accessing_from: opts[:accessing_from] || form.opts[:accessing_from]
          )
          |> Ash.Query.for_read(
            form.action,
            Map.drop(changeset_params, ["_form_type", "_touched", "_union_type"]),
            allow_all_keys_to_be_skipped(source_opts, changeset_params)
          )
          |> add_errors_for_unhandled_params(changeset_params)

        :action ->
          form.resource
          |> Ash.ActionInput.new()
          |> prepare_source.()
          |> set_accessing_from(
            accessing_from: opts[:accessing_from] || form.opts[:accessing_from]
          )
          |> Ash.ActionInput.for_action(
            form.action,
            Map.drop(changeset_params, ["_form_type", "_touched", "_union_type"]),
            allow_all_keys_to_be_skipped(source_opts, changeset_params)
          )
          |> add_errors_for_unhandled_params(changeset_params)
      end

    %{
      form
      | source: new_source,
        forms: forms,
        params: changeset_params,
        added?: form.added?,
        errors: !!opts[:errors],
        submit_errors: nil,
        touched_forms: touched_forms(forms, changeset_params, touched_forms: form.touched_forms)
    }
    |> set_validity()
    |> set_changed?()
    |> carry_over_errors()
    |> update_all_forms(fn form ->
      %{form | just_submitted?: false}
    end)
  end

  @doc """
  Merge the new options with the saved options on a form. See `update_options/2` for more.
  """
  @spec merge_options(t(), Keyword.t()) :: t()
  @spec merge_options(Phoenix.HTML.Form.t(), Keyword.t()) :: Phoenix.HTML.Form.t()
  def merge_options(%Phoenix.HTML.Form{} = form, opts) do
    form.source
    |> update_options(opts)
    |> Phoenix.HTML.FormData.to_form(form.options)
  end

  def merge_options(form, opts) do
    update_options(form, &Keyword.merge(&1, opts))
  end

  @doc """
  Update the saved options on a form.

  When a form is created, options like `actor` and `authorize?` are stored in the `opts` key.
  If you have a case where these options change over time, for example a select box that determines the actor, use this function to override those opts.

  You may want to validate again after this has been changed if it can change the results of your form validation.
  """
  def update_options(%Phoenix.HTML.Form{} = form, fun) do
    form.source
    |> update_options(fun)
    |> Phoenix.HTML.FormData.to_form(form.options)
  end

  def update_options(form, fun) do
    %{form | opts: fun.(form.opts)}
  end

  defp validate_nested_forms(
         form,
         params,
         errors?,
         prev_data_trail,
         matcher,
         trail \\ []
       ) do
    form.form_keys
    |> Enum.reduce({%{}, params}, fn {key, opts}, {forms, params} ->
      case fetch_key(params, opts[:as] || key) do
        {:ok, form_params} when form_params != nil ->
          if opts[:type] == :list do
            form_params =
              if is_map(form_params) do
                form_params
                |> Enum.map(fn {key, value} ->
                  {value, String.to_integer(key)}
                end)
                |> Enum.sort_by(&elem(&1, 1))
              else
                Enum.with_index(form_params || [])
              end

            new_forms =
              form_params
              |> Enum.reduce(forms, fn {params, index}, forms ->
                case Enum.find(form.forms[key] || [], &matcher.(&1, params, form, key, index)) do
                  nil ->
                    opts = update_opts(opts, nil, params)

                    new_form =
                      cond do
                        !opts[:create_action] && !opts[:read_action] ->
                          raise AshPhoenix.Form.NoActionConfigured,
                            path: form.name <> "[#{key}][#{index}]",
                            action: :create_or_read

                        opts[:create_action] ->
                          create_action = opts[:create_action]

                          resource =
                            opts[:create_resource] || opts[:resource] ||
                              raise AshPhoenix.Form.NoResourceConfigured,
                                path: Enum.reverse(trail, [key])

                          for_action(resource, create_action,
                            actor: form.opts[:actor],
                            tenant: form.opts[:tenant],
                            domain: form.domain,
                            params: params,
                            forms: opts[:forms] || [],
                            accessing_from: opts[:managed_relationship],
                            prepare_source: opts[:prepare_source],
                            transform_params: opts[:transform_params],
                            updater: opts[:updater],
                            errors: errors?,
                            warn_on_unhandled_errors?: form.warn_on_unhandled_errors?,
                            prev_data_trail: prev_data_trail,
                            transform_errors: form.transform_errors,
                            as: form.name <> "[#{key}][#{index}]",
                            id: form.id <> "_#{key}_#{index}"
                          )

                        opts[:read_action] ->
                          create_action = opts[:read_action]

                          resource =
                            opts[:read_resource] || opts[:resource] ||
                              raise AshPhoenix.Form.NoResourceConfigured,
                                path: Enum.reverse(trail, [key])

                          for_action(resource, create_action,
                            actor: form.opts[:actor],
                            tenant: form.opts[:tenant],
                            domain: form.domain,
                            params: params,
                            accessing_from: opts[:managed_relationship],
                            prepare_source: opts[:prepare_source],
                            transform_params: opts[:transform_params],
                            updater: opts[:updater],
                            forms: opts[:forms] || [],
                            errors: errors?,
                            warn_on_unhandled_errors?: form.warn_on_unhandled_errors?,
                            prev_data_trail: prev_data_trail,
                            transform_errors: form.transform_errors,
                            as: form.name <> "[#{key}][#{index}]",
                            id: form.id <> "_#{key}_#{index}"
                          )
                      end

                    Map.update(forms, key, [new_form], &(&1 ++ [new_form]))

                  matching_form ->
                    opts = update_opts(opts, matching_form.data, params)

                    validated =
                      validate(
                        matching_form,
                        params,
                        errors: errors?,
                        matcher: matcher,
                        accessing_from: opts[:managed_relationship],
                        prepare_source: opts[:prepare_source],
                        prev_data_trail?: prev_data_trail
                      )
                      |> Map.put(:as, form.name <> "[#{key}][#{index}]")
                      |> Map.put(:id, form.id <> "_#{key}_#{index}")

                    Map.update(forms, key, [validated], fn nested_forms ->
                      nested_forms ++
                        [validated]
                    end)
                end
              end)

            new_params =
              if Map.has_key?(new_forms, opts[:as] || key) do
                new_nested =
                  new_forms
                  |> Map.get(opts[:as] || key)
                  |> List.wrap()
                  |> Enum.with_index()
                  |> Map.new(fn {form, index} ->
                    {to_string(index),
                     apply_or_return(form, form.params, form.transform_params, :nested)}
                  end)

                Map.put(params, to_string(opts[:as] || key), new_nested)
              else
                params
              end

            {new_forms, new_params}
          else
            if is_map(form_params) do
              new_forms =
                if form.forms[key] do
                  opts = update_opts(opts, form.forms[key].data, form_params)

                  new_form =
                    validate(form.forms[key], form_params,
                      errors: errors?,
                      matcher: matcher,
                      transform_params: opts[:transform_params],
                      accessing_from: opts[:managed_relationship],
                      prepare_source: opts[:prepare_source]
                    )

                  Map.put(forms, key, new_form)
                else
                  opts = update_opts(opts, nil, form_params)

                  create_action =
                    opts[:create_action] ||
                      raise AshPhoenix.Form.NoActionConfigured,
                        path: form.name <> "[#{key}]",
                        action: :create

                  resource =
                    opts[:create_resource] || opts[:resource] ||
                      raise AshPhoenix.Form.NoResourceConfigured,
                        path: form.name <> "[#{key}]"

                  new_form =
                    for_action(resource, create_action,
                      actor: form.opts[:actor],
                      tenant: form.opts[:tenant],
                      domain: form.domain,
                      params: form_params,
                      accessing_from: opts[:managed_relationship],
                      prepare_source: opts[:prepare_source],
                      transform_params: opts[:transform_params],
                      warn_on_unhandled_errors?: form.warn_on_unhandled_errors?,
                      updater: opts[:updater],
                      forms: opts[:forms] || [],
                      errors: errors?,
                      prev_data_trail: prev_data_trail,
                      transform_errors: form.transform_errors,
                      as: form.name <> "[#{key}]",
                      id: form.id <> "_#{key}"
                    )

                  Map.put(forms, key, new_form)
                end

              new_params =
                Map.put(
                  params,
                  to_string(opts[:as] || key),
                  apply_or_return(
                    new_forms[key],
                    new_forms[key].params,
                    new_forms[key].transform_params,
                    :nested
                  )
                )

              {new_forms, new_params}
            else
              {forms, params}
            end
          end

        _ ->
          new_forms =
            if Keyword.has_key?(opts, :data) do
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
                |> case do
                  %Ash.Union{value: nil} -> nil
                  value -> value
                end

              cond do
                opts[:update_action] ->
                  update_action = opts[:update_action]

                  if data do
                    form_values =
                      if (opts[:type] || :single) == :single do
                        opts = update_opts(opts, data, %{})

                        for_action(data, update_action,
                          actor: form.opts[:actor],
                          tenant: form.opts[:tenant],
                          domain: form.domain,
                          errors: errors?,
                          accessing_from: opts[:managed_relationship],
                          prepare_source: opts[:prepare_source],
                          transform_params: opts[:transform_params],
                          updater: opts[:updater],
                          warn_on_unhandled_errors?: form.warn_on_unhandled_errors?,
                          prev_data_trail: prev_data_trail,
                          forms: opts[:forms] || [],
                          transform_errors: form.transform_errors,
                          as: form.name <> "[#{key}]",
                          id: form.id <> "_#{key}"
                        )
                      else
                        data
                        |> Enum.with_index()
                        |> Enum.map(fn {data, index} ->
                          opts = update_opts(opts, data, %{})

                          for_action(data, update_action,
                            domain: form.domain,
                            actor: form.opts[:actor],
                            tenant: form.opts[:tenant],
                            errors: errors?,
                            accessing_from: opts[:managed_relationship],
                            prepare_source: opts[:prepare_source],
                            warn_on_unhandled_errors?: form.warn_on_unhandled_errors?,
                            updater: opts[:updater],
                            transform_params: opts[:transform_params],
                            prev_data_trail: prev_data_trail,
                            forms: opts[:forms] || [],
                            transform_errors: form.transform_errors,
                            as: form.name <> "[#{key}][#{index}]",
                            id: form.id <> "_#{key}_#{index}"
                          )
                        end)
                      end

                    Map.put(forms, key, form_values)
                  else
                    forms
                  end

                opts[:read_action] ->
                  read_action = opts[:read_action]

                  if data do
                    form_values =
                      if (opts[:type] || :single) == :single do
                        opts = update_opts(opts, data, %{})

                        pkey =
                          case data do
                            %resource{} ->
                              if Ash.Resource.Info.resource?(resource) do
                                Ash.Resource.Info.primary_key(resource)
                              else
                                []
                              end

                            _ ->
                              []
                          end

                        for_action(data, read_action,
                          actor: form.opts[:actor],
                          tenant: form.opts[:tenant],
                          domain: form.domain,
                          errors: errors?,
                          accessing_from: opts[:managed_relationship],
                          prepare_source: opts[:prepare_source],
                          warn_on_unhandled_errors?: form.warn_on_unhandled_errors?,
                          updater: opts[:updater],
                          transform_params: opts[:transform_params],
                          params: Map.new(pkey, &{to_string(&1), Map.get(data, &1)}),
                          prev_data_trail: prev_data_trail,
                          forms: opts[:forms] || [],
                          data: data,
                          transform_errors: form.transform_errors,
                          as: form.name <> "[#{key}]",
                          id: form.id <> "_#{key}"
                        )
                      else
                        pkey =
                          unless Enum.empty?(data) do
                            Ash.Resource.Info.primary_key(Enum.at(data, 0).__struct__)
                          end

                        data
                        |> Enum.with_index()
                        |> Enum.map(fn {data, index} ->
                          opts = update_opts(opts, data, %{})

                          for_action(data, read_action,
                            actor: form.opts[:actor],
                            tenant: form.opts[:tenant],
                            domain: form.domain,
                            errors: errors?,
                            accessing_from: opts[:managed_relationship],
                            prepare_source: opts[:prepare_source],
                            updater: opts[:updater],
                            prev_data_trail: prev_data_trail,
                            params: Map.new(pkey, &{to_string(&1), Map.get(data, &1)}),
                            transform_params: opts[:transform_params],
                            forms: opts[:forms] || [],
                            data: data,
                            transform_errors: form.transform_errors,
                            as: form.name <> "[#{key}][#{index}]",
                            id: form.id <> "_#{key}_#{index}"
                          )
                        end)
                      end

                    Map.put(forms, key, form_values)
                  else
                    forms
                  end

                true ->
                  cond do
                    !data ->
                      forms

                    opts[:type] == :list ->
                      form_values =
                        data
                        |> List.wrap()
                        |> Enum.with_index()
                        |> Enum.map(fn {data, index} ->
                          opts = update_opts(opts, data, nil)

                          if opts[:update_action] do
                            for_action(data, opts[:update_action],
                              actor: form.opts[:actor],
                              tenant: form.opts[:tenant],
                              domain: form.domain,
                              errors: errors?,
                              accessing_from: opts[:managed_relationship],
                              prepare_source: opts[:prepare_source],
                              updater: opts[:updater],
                              prev_data_trail: prev_data_trail,
                              transform_params: opts[:transform_params],
                              forms: opts[:forms] || [],
                              data: data,
                              transform_errors: form.transform_errors,
                              as: form.name <> "[#{key}][#{index}]",
                              id: form.id <> "_#{key}_#{index}"
                            )
                          end
                        end)

                      Map.put(forms, key, Enum.filter(form_values, & &1))

                    true ->
                      opts = update_opts(opts, data, nil)

                      pkey =
                        case data do
                          %struct{} ->
                            if Ash.Resource.Info.resource?(struct) do
                              Ash.Resource.Info.primary_key(struct)
                            else
                              []
                            end

                          _ ->
                            []
                        end

                      form_value =
                        if opts[:update_action] do
                          for_action(data, opts[:update_action],
                            actor: form.opts[:actor],
                            tenant: form.opts[:tenant],
                            domain: form.domain,
                            errors: errors?,
                            accessing_from: opts[:managed_relationship],
                            prepare_source: opts[:prepare_source],
                            warn_on_unhandled_errors?: form.warn_on_unhandled_errors?,
                            updater: opts[:updater],
                            transform_params: opts[:transform_params],
                            params: Map.new(pkey, &{to_string(&1), Map.get(data, &1)}),
                            prev_data_trail: prev_data_trail,
                            forms: opts[:forms] || [],
                            data: opts[:data],
                            transform_errors: form.transform_errors,
                            as: form.name <> "[#{key}]",
                            id: form.id <> "_#{key}"
                          )
                        end

                      Map.put(forms, key, form_value)
                  end
              end
            else
              forms
            end

          {new_forms, params}
      end
    end)
  end

  @submit_opts [
    force?: [
      type: :boolean,
      default: false,
      doc: "Submit the form even if it is invalid in its current state."
    ],
    action_opts: [
      type: :keyword_list,
      default: [],
      doc: "Opts to pass to the call to Ash when calling the action."
    ],
    errors: [
      type: :boolean,
      default: true,
      doc: "Wether or not to show errors after submitting."
    ],
    override_params: [
      type: :any,
      doc: """
      If specified, then the params are not extracted from the form.

      How this different from `params`: providing `params` is simply results in calling `validate(form, params)` before proceeding.
      The values that are passed into the action are then extracted from the form using `params/2`. With `override_params`, the form
      is not validated again, and the `override_params` are passed directly into the action.
      """
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
    read_one?: [
      type: :boolean,
      default: false,
      doc: """
      If submitting a read form, a single result will be returned (via read_one) instead of a list of results.

      Ignored for non-read forms.
      """
    ],
    before_submit: [
      type: {:fun, 1},
      doc:
        "A function to apply to the source (changeset or query) just before submitting the action. Must return the modified changeset."
    ]
  ]

  @doc """
  Submits the form.

  If the submission returns an error, the resulting form can be rerendered. Any nested
  errors will be passed down to the corresponding form for that input.

  Options:

  #{Spark.Options.docs(@submit_opts)}
  """
  @spec submit(t(), Keyword.t()) ::
          {:ok, Ash.Resource.record() | nil | list(Ash.Notifier.Notification.t())}
          | {:ok, Ash.Resource.record(), list(Ash.Notifier.Notification.t())}
          | :ok
          | {:error, t()}

  @spec submit(Phoenix.HTML.Form.t(), Keyword.t()) ::
          {:ok, Ash.Resource.record() | nil | list(Ash.Notifier.Notification.t())}
          | {:ok, Ash.Resource.record(), list(Ash.Notifier.Notification.t())}
          | :ok
          | {:error, Phoenix.HTML.Form.t()}
  def submit(form, opts \\ [])

  def submit(%Phoenix.HTML.Form{} = form, opts) do
    form.source
    |> submit(opts)
    |> case do
      {:error, new_form} ->
        {:error, Phoenix.HTML.FormData.to_form(new_form, form.options)}

      other ->
        other
    end
  end

  def submit(form, opts) do
    if opts[:api_opts] do
      raise ArgumentError, """
      The `api_opts` option has been renamed to `action_opts`. Please update your code accordingly.
      """
    end

    changeset_opts =
      drop_form_opts(form.opts)

    form =
      if opts[:params] do
        validate(
          form,
          opts[:params],
          Keyword.take(opts, Keyword.keys(@validate_opts))
        )
      else
        form
      end

    form =
      if Keyword.get(opts, :errors, true) do
        update_all_forms(form, &%{&1 | errors: true})
      else
        form
      end

    opts = validate_opts_with_extra_keys(opts, @submit_opts)
    before_submit = opts[:before_submit] || (& &1)

    if form.valid? || opts[:force?] do
      changeset_params =
        opts[:override_params] || params(form)

      prepare_source = form.prepare_source || (& &1)

      {original_changeset_or_query, result} =
        case form.type do
          :create ->
            form.resource
            |> Ash.Changeset.new()
            |> prepare_source.()
            |> Ash.Changeset.for_create(
              form.source.action.name,
              changeset_params,
              allow_all_keys_to_be_skipped(changeset_opts, changeset_params)
            )
            |> before_submit.()
            |> with_changeset(&Ash.create(&1, opts[:action_opts] || []))

          :update ->
            form.original_data
            |> Ash.Changeset.new()
            |> prepare_source.()
            |> Ash.Changeset.for_update(
              form.source.action.name,
              changeset_params,
              allow_all_keys_to_be_skipped(changeset_opts, changeset_params)
            )
            |> before_submit.()
            |> with_changeset(&Ash.update(&1, opts[:action_opts] || []))

          :destroy ->
            form.original_data
            |> Ash.Changeset.new()
            |> prepare_source.()
            |> Ash.Changeset.for_destroy(
              form.source.action.name,
              changeset_params,
              allow_all_keys_to_be_skipped(changeset_opts, changeset_params)
            )
            |> before_submit.()
            |> with_changeset(&Ash.destroy(&1, opts[:action_opts] || []))

          :read ->
            if opts[:read_one?] do
              form.resource
              |> Ash.Query.new()
              |> prepare_source.()
              |> Ash.Query.for_read(
                form.source.action.name,
                changeset_params,
                allow_all_keys_to_be_skipped(changeset_opts, changeset_params)
              )
              |> before_submit.()
              |> with_changeset(&Ash.read_one(&1, opts[:action_opts] || []))
            else
              form.resource
              |> Ash.Query.new()
              |> prepare_source.()
              |> Ash.Query.for_read(
                form.source.action.name,
                changeset_params,
                allow_all_keys_to_be_skipped(changeset_opts, changeset_params)
              )
              |> before_submit.()
              |> with_changeset(&Ash.read(&1, opts[:action_opts] || []))
            end

          :action ->
            form.resource
            |> Ash.ActionInput.new()
            |> prepare_source.()
            |> Ash.ActionInput.for_action(
              form.source.action.name,
              changeset_params,
              allow_all_keys_to_be_skipped(changeset_opts, changeset_params)
            )
            |> before_submit.()
            |> with_changeset(&Ash.run_action(&1, opts[:action_opts] || []))
        end

      case result do
        {:error, %Ash.Error.Invalid.NoSuchResource{resource: resource}} ->
          raise """
          Resource #{inspect(resource)} not found in domain #{inspect(form.domain)}
          """

        {:error, %{query: query} = error} when form.type == :read ->
          if opts[:raise?] do
            errors =
              if query do
                query.errors
              else
                error
              end

            raise Ash.Error.to_error_class(errors, query: query)
          else
            errors =
              error
              |> List.wrap()
              |> Enum.flat_map(&expand_error/1)

            query = query || %{original_changeset_or_query | errors: errors}

            {:error,
             set_action_errors(
               %{form | source: query},
               errors
             )
             |> carry_over_errors()
             |> update_all_forms(fn form ->
               %{form | just_submitted?: true, submitted_once?: true}
             end)
             |> set_changed?()}
          end

        {:error, %{action_input: action_input} = error} when form.type == :action_input ->
          if opts[:raise?] do
            errors =
              if action_input do
                action_input.errors
              else
                error
              end

            raise Ash.Error.to_error_class(errors, action_input: action_input)
          else
            errors =
              error
              |> List.wrap()
              |> Enum.flat_map(&expand_error/1)

            action_input = action_input || %{original_changeset_or_query | errors: errors}

            {:error,
             set_action_errors(
               %{form | source: action_input},
               errors
             )
             |> carry_over_errors()
             |> update_all_forms(fn form ->
               %{form | just_submitted?: true, submitted_once?: true}
             end)
             |> set_changed?()}
          end

        {:error, %{changeset: changeset} = error}
        when form.type != :read ->
          if opts[:raise?] do
            errors =
              if changeset do
                changeset.errors
              else
                error
              end

            raise Ash.Error.to_error_class(errors, changeset: changeset)
          else
            errors =
              error
              |> List.wrap()
              |> Enum.flat_map(&expand_error/1)

            changeset = changeset || %{original_changeset_or_query | errors: errors}

            {:error,
             set_action_errors(
               %{form | source: changeset},
               errors
             )
             |> carry_over_errors()
             |> update_all_forms(fn form ->
               %{form | just_submitted?: true, submitted_once?: true}
             end)}
          end

        other ->
          other
      end
    else
      if opts[:raise?] do
        errors =
          case ash_errors(form, for_path: :all) do
            [] ->
              [
                Ash.Error.Unknown.UnknownError.exception(
                  error: "Form is invalid, but no errors were found on the form."
                )
              ]

            errors ->
              errors
          end

        raise Ash.Error.to_error_class(errors)
      else
        {:error,
         form
         |> update_all_forms(fn form -> %{form | submitted_once?: true, just_submitted?: true} end)
         |> synthesize_action_errors()
         |> carry_over_errors()}
      end
    end
  end

  defp carry_over_errors(form, additional_errors \\ nil) do
    {these_errors, further_path_errors} =
      form.source.errors
      |> AshPhoenix.FormData.Helpers.unwrap_errors()
      |> Enum.concat(additional_errors || [])
      |> Enum.split_with(&(&1.path == []))

    # not the first iteration
    form =
      if additional_errors != nil do
        %{form | source: %{form.source | errors: these_errors}}
      else
        form
      end

    Map.update!(form, :forms, fn nested_forms ->
      Map.new(nested_forms, fn
        {key, data} when is_list(data) ->
          {key,
           data
           |> Enum.with_index()
           |> Enum.map(fn {form, index} ->
             further =
               further_path_errors
               |> Enum.filter(&List.starts_with?(&1.path, [key, index]))
               |> Enum.map(&%{&1 | path: Enum.drop(&1.path, 2)})

             carry_over_errors(form, further)
           end)}

        {key, form} ->
          further =
            further_path_errors
            |> Enum.filter(&List.starts_with?(&1.path, [key]))
            |> Enum.map(&%{&1 | path: Enum.drop(&1.path, 1)})

          {key, carry_over_errors(form, further)}
      end)
    end)
  end

  defp allow_all_keys_to_be_skipped(changeset_opts, changeset_params) do
    keys = Map.keys(changeset_params)
    Keyword.update(changeset_opts, :skip_unknown_inputs, keys, &(&1 ++ keys))
  end

  defp with_changeset(changeset, func) do
    {changeset, func.(changeset)}
  end

  @doc """
  Same as `submit/2`, but raises an error if the submission fails.
  """
  @spec submit!(t(), Keyword.t()) :: Ash.Resource.record() | :ok | no_return
  def submit!(form, opts \\ []) do
    case submit(form, Keyword.put(opts, :raise?, true)) do
      {:ok, value} ->
        value

      {:ok, result, notifications} ->
        {result, notifications}

      :ok ->
        :ok

      {:error, error} ->
        raise Ash.Error.to_error_class(error)
    end
  end

  @update_form_opts [
    mark_as_touched?: [
      type: :boolean,
      default: true,
      doc: "Whether or not to mark the path to the updating form as touched."
    ]
  ]

  @doc """
  Mark a field or fields as touched

  To mark nested fields as touched use with `update_form/4` or `update_forms_at_path/4`
  """
  def touch(form, fields) when is_list(fields) do
    Enum.reduce(fields, form, &touch(&2, &1))
  end

  def touch(form, field) do
    %{form | touched_forms: MapSet.put(form.touched_forms || MapSet.new(), to_string(field))}
  end

  @doc """
  Updates the list of forms matching a given path. Does not validate that the path points at a single form like `update_form/4`.

  Additionally, if it gets to a list of child forms and the next part of the path is not an integer,
  it will update all of the forms at that path.
  """
  def update_forms_at_path(form, path, func, opts \\ [])

  def update_forms_at_path(nil, _, _, _), do: nil

  def update_forms_at_path(forms, [] = path, func, opts) when is_list(forms) do
    Enum.map(forms, &update_forms_at_path(&1, path, func, opts))
  end

  def update_forms_at_path(forms, [next | rest] = path, func, opts) when is_list(forms) do
    case Integer.parse(next) do
      {integer, ""} ->
        List.update_at(forms, integer, &update_forms_at_path(&1, rest, func, opts))

      _ ->
        Enum.map(forms, &update_forms_at_path(&1, path, func, opts))
    end
  end

  def update_forms_at_path(%Phoenix.HTML.Form{} = form, path, func, opts) do
    form.source
    |> update_forms_at_path(path, func, opts)
    |> Phoenix.HTML.FormData.to_form(form.options)
  end

  def update_forms_at_path(form, path, func, opts) do
    opts = Spark.Options.validate!(opts, @update_form_opts)

    path =
      case path do
        [] ->
          []

        path when is_list(path) ->
          path

        path ->
          path
          |> Plug.Conn.Query.decode()
          |> decoded_to_list()
      end

    case path do
      [] ->
        func.(form)

      [key | rest] ->
        new_forms =
          form.forms
          |> Map.new(fn {key, value} ->
            if to_string(key) == key do
              {key, update_forms_at_path(value, rest, func, opts)}
            else
              {key, value}
            end
          end)

        if opts[:mark_as_touched?] do
          %{
            form
            | forms: new_forms,
              touched_forms: MapSet.put(form.touched_forms, key)
          }
        else
          %{
            form
            | forms: new_forms
          }
        end
    end
  end

  @doc """
  Updates the form at the provided path using the given function.

  Marks all forms along the path as touched by default. To prevent it, provide `mark_as_touched?: false`.

  This can be useful if you have a button that should modify a nested form in some way, for example.
  """
  @spec update_form(
          t(),
          list(atom | integer) | String.t() | atom,
          (t() -> t()) | ([t()] -> [t()])
        ) ::
          t()
  @spec update_form(
          Phoenix.HTML.Form.t(),
          list(atom | integer) | String.t(),
          (t() -> t()) | ([t()] -> [t()])
        ) ::
          Phoenix.HTML.Form.t()
  def update_form(form, path, func, opts \\ [])

  def update_form(form, path, func, opts) when is_atom(path) do
    update_form(form, [path], func, opts)
  end

  def update_form(%Phoenix.HTML.Form{} = form, path, func, opts) do
    form.source
    |> update_form(path, func, opts)
    |> Phoenix.HTML.FormData.to_form(form.options)
  end

  def update_form(form, path, func, opts) do
    opts = Spark.Options.validate!(opts, @update_form_opts)

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

        if opts[:mark_as_touched?] do
          %{
            form
            | forms: new_forms,
              touched_forms: MapSet.put(form.touched_forms, to_string(atom))
          }
        else
          %{
            form
            | forms: new_forms
          }
        end

      [atom | rest] ->
        new_forms =
          form.forms
          |> Map.update!(atom, &update_form(&1, rest, func, opts))

        if opts[:mark_as_touched?] do
          %{
            form
            | forms: new_forms,
              touched_forms: MapSet.put(form.touched_forms, to_string(atom))
          }
        else
          %{
            form
            | forms: new_forms
          }
        end
    end
  end

  @doc """
  Returns true if a given form path exists in the form
  """
  @spec has_form?(t(), path()) :: boolean
  def has_form?(form, path) do
    form = to_form!(form)
    not is_nil(get_form(form, path))
  rescue
    InvalidPath ->
      false
  end

  @doc """
  Gets the form at the specified path
  """
  @spec get_form(t() | Phoenix.HTML.Form.t(), path()) :: t() | nil
  def get_form(form, path) do
    form = to_form!(form)

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
        |> find_form(integer, form.form_keys[atom])
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

  defp to_form!(%__MODULE__{} = form), do: form
  defp to_form!(%Phoenix.HTML.Form{source: %__MODULE__{} = form}), do: form

  defp to_form!(%Phoenix.HTML.Form{source: inner_form}) do
    raise ArgumentError, """
    Expected to receive either an `%AshPhoenix.Form{}` or a `%Phoenix.HTML.Form{}` with `%AshPhoenix.Form{}` as its source.

    Got a `%Phoenix.HTML.Form{}` with source: #{inspect(inner_form)}
    """
  end

  defp to_form!(form) do
    raise ArgumentError, """
    Expected to receive either an `%AshPhoenix.Form{}` or a `%Phoenix.HTML.Form{}` with `%AshPhoenix.Form{}` as its source.

    Got: #{inspect(form)}
    """
  end

  defp add_index(form_params, index, opts) do
    if opts[:sparse?] do
      Map.put(form_params, "_index", to_string(index))
    else
      form_params
    end
  end

  defp find_form(forms, index, config) do
    if config[:sparse?] do
      Enum.find(forms, fn form ->
        form.params["_index"] == to_string(index)
      end) ||
        Enum.at(forms, index)
    else
      Enum.at(forms, index)
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

      `%{[:comments, 0] => [body: "is invalid"], ...}`
      """
    ]
  ]

  @doc """
  Returns the errors on the form.

  By default, only errors on the form being passed in (not nested forms) are provided.
  Use `for_path` to get errors for nested forms.

  #{Spark.Options.docs(@errors_opts)}
  """
  @spec errors(t() | Phoenix.HTML.Form.t(), Keyword.t()) ::
          ([{atom, {String.t(), Keyword.t()}}]
           | [String.t()]
           | [{atom, String.t()}])
          | %{
              list => [{atom, {String.t(), Keyword.t()}}] | [String.t()] | [{atom, String.t()}]
            }
  def errors(form, opts \\ []) do
    form = to_form!(form)
    opts = validate_opts_with_extra_keys(opts, @errors_opts)

    case opts[:for_path] do
      :all ->
        gather_errors(form, opts[:format])

      [] ->
        if form.errors do
          errors =
            transform_errors(form, form.source.errors, [], form.form_keys)

          errors
          |> List.wrap()
          |> format_errors(opts[:format])
        else
          []
        end

      path ->
        form
        |> gather_errors(opts[:format])
        |> Map.get(path)
        |> List.wrap()
    end
  end

  def ash_errors(form, opts \\ []) do
    form = to_form!(form)
    opts = validate_opts_with_extra_keys(opts, @errors_opts)

    case opts[:for_path] do
      :all ->
        gather_ash_errors(form, opts[:format])

      [] ->
        if form.errors do
          List.wrap(form.source.errors)
        else
          []
        end

      path ->
        form
        |> gather_ash_errors(opts[:format])
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
          |> Enum.reduce(acc, fn {nested_form, i}, acc ->
            gather_errors(nested_form, format, acc, trail ++ [key, i])
          end)

        nested_form ->
          gather_errors(nested_form, format, acc, trail ++ [key])
      end
    end)
  end

  defp gather_ash_errors(form, format, acc \\ [], trail \\ []) do
    errors = ash_errors(form, format: format)

    acc = acc ++ errors

    Enum.reduce(form.forms, acc, fn {key, forms}, acc ->
      case forms do
        [] ->
          acc

        nil ->
          acc

        forms when is_list(forms) ->
          forms
          |> Enum.with_index()
          |> Enum.reduce(acc, fn {nested_form, i}, acc ->
            gather_ash_errors(nested_form, format, acc, trail ++ [key, i])
          end)

        nested_form ->
          gather_ash_errors(nested_form, format, acc, trail ++ [key])
      end
    end)
  end

  @doc false
  @spec errors_for(t() | Phoenix.HTML.Form.t(), path(), type :: :simple | :raw | :plaintext) ::
          [{atom, {String.t(), Keyword.t()}}] | [String.t()] | map | nil
  @deprecated "Use errors/2 instead"
  def errors_for(form, path, type \\ :raw) do
    form = to_form!(form)

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
  def set_data(%Phoenix.HTML.Form{} = form, data) do
    form.source
    |> set_data(data)
    |> Phoenix.HTML.FormData.to_form(form.options)
  end

  def set_data(form, data) do
    case form.source do
      %Ash.Changeset{} = source ->
        %{form | data: data, source: %{source | data: data}}

      %Ash.Query{} ->
        %{form | data: data}

      %Ash.ActionInput{} ->
        %{form | data: data}
    end
  end

  @doc """
  Clears a given input's value on a form.

  Accepts a field (atom) or a list of fields (atoms) as a second argument.
  """
  @spec clear_value(t(), atom | [atom]) :: t()
  def clear_value(%Phoenix.HTML.Form{} = form, field_or_fields) do
    form.source
    |> clear_value(field_or_fields)
    |> Phoenix.HTML.FormData.to_form(form.options)
  end

  def clear_value(form, field_or_fields) when is_list(field_or_fields) do
    Enum.reduce(field_or_fields, form, &clear_value(&2, &1))
  end

  def clear_value(form, field) do
    string_and_atom = [field, to_string(field)]

    common_dropped = %{
      form
      | params: Map.drop(form.params, string_and_atom),
        source: %{
          form.source
          | params: Map.drop(form.source.params, string_and_atom),
            arguments: Map.drop(form.source.arguments, string_and_atom)
        }
    }

    case form.source do
      %Ash.Changeset{} = _source ->
        %{
          common_dropped
          | source:
              %{
                common_dropped.source
                | attributes: Map.drop(common_dropped.source.attributes, string_and_atom)
              }
              |> clear_casted_keys(string_and_atom)
        }

      _ ->
        common_dropped
    end
  end

  defp clear_casted_keys(
         %{casted_arguments: casted_arguments, casted_attributes: casted_attributes} = changeset,
         keys
       ) do
    %{
      changeset
      | casted_arguments: Map.drop(casted_arguments, keys),
        casted_attributes: Map.drop(casted_attributes, keys)
    }
  end

  defp clear_casted_keys(changeset, _keys), do: changeset

  @doc """
  Gets the value for a given field in the form.
  """
  @spec value(t() | Phoenix.HTML.Form.t(), atom) :: any()
  def value(form, field) do
    form = to_form!(form)
    do_value(form, field)
  end

  defp do_value(%{source: %Ash.Changeset{} = changeset} = form, field) do
    with :error <- get_nested(form, field),
         :error <- get_invalid_value(changeset, field),
         :error <- get_changing_value(changeset, field),
         :error <- get_casted_value(changeset, field),
         :error <- Ash.Changeset.fetch_argument(changeset, field),
         :error <- get_non_attribute_non_argument_param(changeset, form, field),
         :error <- Map.fetch(changeset.data, field) do
      nil
    else
      {:ok, %Ash.NotLoaded{}} ->
        nil

      {:ok, value} ->
        value
    end
  end

  defp do_value(%{source: %Ash.Query{} = query, data: data} = form, field) do
    with :error <- get_nested(form, field),
         :error <- Ash.Query.fetch_argument(query, field),
         :error <- Map.fetch(query.params, to_string(field)),
         :error <- Map.fetch(data || %{}, field) do
      nil
    else
      {:ok, %Ash.NotLoaded{}} ->
        nil

      {:ok, value} ->
        value
    end
  end

  defp do_value(%{source: %Ash.ActionInput{} = action_input, data: data} = form, field) do
    with :error <- get_nested(form, field),
         :error <- Ash.ActionInput.fetch_argument(action_input, field),
         :error <- Map.fetch(action_input.params, to_string(field)),
         :error <- Map.fetch(data || %{}, field) do
      nil
    else
      {:ok, %Ash.NotLoaded{}} ->
        nil

      {:ok, value} ->
        value
    end
  end

  defp get_nested(form, field) do
    Map.fetch(form.forms, field)
  end

  # `casted_arguments` and `casted_attributes` added in Ash 2.20+
  defp get_casted_value(
         %{casted_arguments: casted_arguments, casted_attributes: casted_attributes},
         field
       )
       when is_atom(field) do
    with :error <- Map.fetch(casted_arguments, field),
         :error <- Map.fetch(casted_attributes, field),
         string_field = to_string(field),
         :error <- Map.fetch(casted_arguments, string_field) do
      Map.fetch(casted_attributes, string_field)
    end
  end

  defp get_casted_value(
         %{casted_arguments: casted_arguments, casted_attributes: casted_attributes},
         field
       )
       when is_binary(field) do
    with :error <- Map.fetch(casted_arguments, field),
         :error <- Map.fetch(casted_attributes, field) do
      Map.fetch(casted_attributes, field)
    end
  end

  defp get_casted_value(_, _), do: :error

  defp get_invalid_value(changeset, field) when is_atom(field) do
    if field in changeset.invalid_keys do
      with :error <- get_casted_value(changeset, field),
           :error <- Map.fetch(changeset.params, field) do
        Map.fetch(changeset.params, to_string(field))
      end
    else
      :error
    end
  end

  defp get_invalid_value(changeset, field) when is_binary(field) do
    if Enum.any?(changeset.invalid_keys, &(to_string(&1) == field)) do
      with :error <- Map.fetch(changeset.params, field) do
        Map.fetch(changeset.params, to_string(field))
      end
    else
      :error
    end
  end

  defp get_changing_value(changeset, field) do
    Map.fetch(changeset.attributes, field)
  end

  defp get_non_attribute_non_argument_param(changeset, form, field) do
    if Ash.Resource.Info.attribute(changeset.resource, field) ||
         Enum.any?(changeset.action.arguments, &(&1.name == field)) do
      with :error <- Map.fetch(changeset.params, field) do
        Map.fetch(changeset.params, to_string(field))
      end
    else
      Map.fetch(AshPhoenix.Form.params(form), Atom.to_string(field))
    end
  end

  @doc """
  Toggles the form to be ignored or not ignored.

  To set this manually in an html form, use the field `:_ignored` and set it
  to the string "true". Any other value will not result in the form being ignored.
  """
  @spec ignore(t()) :: t()
  def ignore(%Phoenix.HTML.Form{} = form) do
    form.source
    |> ignore()
    |> Phoenix.HTML.FormData.to_form(form.options)
  end

  def ignore(form) do
    if ignored?(form) do
      %{form | params: Map.delete(form.params, "_ignore")}
    else
      %{form | params: Map.put(form.params, "_ignore", "true")}
    end
  end

  @doc """
  Returns true if the form is ignored
  """
  @spec ignored?(t() | Phoenix.HTML.Form.t()) :: boolean
  def ignored?(form) do
    form = to_form!(form)
    form.params["_ignore"] == "true"
  end

  @doc """
  Returns the parameters from the form that would be submitted to the action.

  This can be useful if you want to get the parameters and manipulate them/build a custom changeset
  afterwards.
  """
  @spec params(t() | Phoenix.HTML.Form.t()) :: map
  def params(form, opts \\ []) do
    form = to_form!(form)
    # These options aren't documented because they are still experimental
    hidden? = Keyword.get(opts, :hidden?, true)

    excluded_empty_fields =
      Keyword.get(
        opts,
        :exclude_fields_if_empty,
        Keyword.get(form.opts, :exclude_fields_if_empty, [])
      )

    indexer = opts[:indexer]
    indexed_lists? = opts[:indexed_lists?] || not is_nil(indexer) || false
    transform = opts[:transform]
    transform? = Keyword.get(opts, :transform?, true)
    produce = opts[:produce]
    set_params = opts[:set_params]
    only_touched? = Keyword.get(opts, :only_touched?, true)
    filter = opts[:filter] || fn _ -> true end

    form_keys =
      form.form_keys
      |> Keyword.keys()
      |> Enum.flat_map(&[&1, to_string(&1)])

    params =
      form.params
      |> Map.drop(form_keys)
      |> exclude_empty_fields(excluded_empty_fields)

    params =
      if only_touched? do
        Map.take(params, Enum.to_list(form.touched_forms))
      else
        params
      end

    params =
      if hidden? do
        hidden = hidden_fields(form)
        hidden_stringified = hidden |> Map.new(fn {field, value} -> {to_string(field), value} end)
        Map.merge(hidden_stringified, params)
      else
        params
      end

    untransformed_params =
      form.form_keys
      |> only_touched(form, only_touched?)
      |> Enum.reduce(params, fn {key, config}, params ->
        for_name = to_string(config[:for] || key)

        case config[:type] || :single do
          :single ->
            nested_form = form.forms[key]

            if nested_form && filter.(nested_form) do
              opts =
                Keyword.put(
                  opts,
                  :exclude_fields_if_empty,
                  Keyword.get(excluded_empty_fields, key, [])
                )

              nested_params = params(nested_form, opts)

              if nested_params["_ignore"] == "true" do
                Map.put(params, for_name, nil)
              else
                if get_form_key(form.form_keys, key)[:merge?] do
                  Map.merge(nested_params || %{}, params)
                else
                  nested_params =
                    apply_or_return(
                      nested_form,
                      nested_params,
                      nested_form.transform_params,
                      :nested,
                      transform?
                    )

                  Map.put(params, for_name, nested_params)
                end
              end
            else
              if touched?(form, key) || !only_touched? do
                Map.put(params, for_name, nil)
              else
                params
              end
            end

          :list ->
            if form.forms[key] do
              forms =
                form.forms[key]
                |> Kernel.||([])
                |> Enum.filter(fn form ->
                  filter.(form) && form.params["_ignore"] != "true"
                end)

              if indexed_lists? do
                params
                |> Map.put_new(for_name, %{})
                |> Map.update!(for_name, fn current ->
                  if indexer do
                    Enum.reduce(forms, current, fn form, current ->
                      nested_params =
                        apply_or_return(
                          form,
                          params(form, opts),
                          form.transform_params,
                          :nested,
                          transform?
                        )

                      Map.put(current, indexer.(form), nested_params)
                    end)
                  else
                    max =
                      current
                      |> Map.keys()
                      |> Enum.map(&String.to_integer/1)
                      |> Enum.max(fn -> -1 end)

                    forms
                    |> Enum.reduce({current, max + 1}, fn form, {current, i} ->
                      nested_params =
                        apply_or_return(
                          form,
                          params(form, opts),
                          form.transform_params,
                          :nested,
                          transform?
                        )

                      {Map.put(current, to_string(i), nested_params), i + 1}
                    end)
                    |> elem(0)
                  end
                end)
              else
                params
                |> Map.put_new(for_name, [])
                |> Map.update!(for_name, fn current ->
                  current ++
                    Enum.map(forms, fn form ->
                      apply_or_return(
                        form,
                        params(form, opts),
                        form.transform_params,
                        :nested,
                        transform?
                      )
                    end)
                end)
              end
            else
              if touched?(form, key) || !only_touched? do
                Map.put(params, for_name, [])
              else
                params
              end
            end
        end
      end)

    with_produced_params =
      if produce do
        Map.merge(
          produce.(form),
          untransformed_params
        )
      else
        untransformed_params
      end

    with_set_params =
      if set_params do
        Map.merge(with_produced_params, set_params.(form))
      else
        with_produced_params
      end

    transformed_via_option =
      if transform do
        Map.new(with_set_params, transform)
      else
        with_set_params
      end

    apply_or_return(form, transformed_via_option, form.transform_params, :validate, transform?)
  end

  defp only_touched(form_keys, form, true) do
    Enum.filter(form_keys, fn {key, _} ->
      touched?(form, key)
    end)
  end

  defp only_touched(form_keys, _, _), do: form_keys

  defp touched?(form, key), do: MapSet.member?(form.touched_forms, to_string(key))

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
    validate?: [
      type: :boolean,
      default: true,
      doc: "Validates the new full form."
    ],
    validate_opts: [
      type: :any,
      default: [],
      doc:
        "Options to pass to `validate`. Only used if `validate?` is set to `true` (the default)"
    ],
    type: [
      type: {:one_of, [:read, :create, :update, :destroy]},
      default: :create,
      doc:
        "If `type` is set to `:read`, the form will be created for a read action. A hidden field will be set in the form called `_form_type` to track this information."
    ],
    data: [
      type: :any,
      doc: """
      The data to set backing the form. Generally you'd only want to do this if you are adding a form with `type: :read` additionally.
      """
    ]
  ]

  @doc """
  Adds an error to the source underlying the form.

  This can be used for adding errors from different sources to a form. Keep in mind, if they don't match
  a field on the form (typically extracted via the `field` key in the error), they won't be displayed by default.

  # Options

  - `:path` - The path to add the error to. If the error(s) already have a path, don't specify a path yourself.
  """
  def add_error(form, path, opts \\ [])

  def add_error(%Phoenix.HTML.Form{} = form, path, opts) do
    form.source
    |> add_error(path, opts)
    |> Phoenix.HTML.FormData.to_form(form.options)
  end

  def add_error(form, error, opts) do
    error = Ash.Error.to_error_class(error)

    error =
      if opts[:path] do
        Ash.Error.set_path(error, opts[:path])
      else
        error
      end

    new_source =
      case form.source do
        %Ash.Query{} ->
          Ash.Query.add_error(form.source, error)

        %Ash.Changeset{} ->
          Ash.Changeset.add_error(form.source, error)

        %Ash.ActionInput{} ->
          Ash.ActionInput.add_error(form.source, error)
      end

    %{form | source: new_source}
    |> set_validity()
    |> carry_over_errors()
  end

  @doc """
  Adds a new form at the provided path.

  Doing this requires that the form has a `create_action` and a `resource` configured.

  `path` can be one of two things:

  1. A list of atoms and integers that lead to a form in the `forms` option provided. `[:posts, 0, :comments]` to add a comment to the first post.
  2. The html name of the form, e.g `form[posts][0][comments]` to mimic the above

  If you pass parameters to this function, keep in mind that, unless they are string keyed in
  the same shape they might come from your form, then the result of `params/1` will reflect that,
  i.e `add_form(form, "foo", params: %{bar: 10})`, could produce params like `%{"field" => value, "foo" => [%{bar: 10}]}`.
  Notice how they are not string keyed as you would expect. However, once the form is changed (in liveview) and a call
  to `validate/2` is made with that input, then the parameters would become what you'd expect. In this way, if you are using
  `add_form` with not string keys/values you may not be able to depend on the shape of the `params` map (which you should ideally
  not depend on anyway).

  #{Spark.Options.docs(@add_form_opts)}
  """
  @spec add_form(t(), path, Keyword.t()) :: t()
  @spec add_form(Phoenix.HTML.Form.t(), path, Keyword.t()) :: Phoenix.HTML.Form.t()
  def add_form(form, path, opts \\ [])

  def add_form(%Phoenix.HTML.Form{} = form, path, opts) do
    form.source
    |> add_form(path, opts)
    |> Phoenix.HTML.FormData.to_form(form.options)
  end

  def add_form(form, path, opts) do
    opts = Spark.Options.validate!(opts, @add_form_opts)

    path = parse_path!(form, path, skip_last?: true)

    form =
      do_add_form(form, path, opts, [], form.transform_errors)

    if opts[:validate?] do
      validate(form, params(form, transform?: false, hidden?: true), opts[:validate_opts] || [])
    else
      set_changed?(form)
    end
  end

  @remove_form_opts [
    validate?: [
      type: :boolean,
      default: true,
      doc: "Validates the new full form."
    ],
    validate_opts: [
      type: :any,
      default: [],
      doc:
        "Options to pass to `validate`. Only used if `validate?` is set to `true` (the default)"
    ]
  ]

  @doc """
  Removes a form at the provided path.

  See `add_form/3` for more information on the `path` argument.

  If you are not using liveview, and you want to support removing forms that were created based on the `data`
  option from the browser, you'll need to include in the form submission a custom list of strings to remove, and
  then manually iterate over them in your controller, for example:

  ```elixir
  Enum.reduce(removed_form_paths, form, &AshPhoenix.Form.remove_form(&2, &1))
  ```

  #{Spark.Options.docs(@remove_form_opts)}
  """
  @spec remove_form(t(), path, Keyword.t()) :: t()
  @spec remove_form(Phoenix.HTML.Form.t(), path, Keyword.t()) :: Phoenix.HTML.Form.t()
  def remove_form(form, path, opts \\ [])

  def remove_form(%Phoenix.HTML.Form{} = form, path, opts) do
    form.source
    |> remove_form(path, opts)
    |> Phoenix.HTML.FormData.to_form(form.options)
  end

  def remove_form(form, path, opts) do
    opts = Spark.Options.validate!(opts, @remove_form_opts)

    if has_form?(form, path) do
      path = parse_path!(form, path)

      form =
        do_remove_form(form, path, [])

      form = set_changed?(form)

      if opts[:validate?] do
        validate(form, params(form, transform?: false, hidden?: true), opts[:validate_opts] || [])
      else
        form
      end
    else
      form
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

  defp set_changed?(form) do
    %{form | changed?: changed?(form)}
  end

  defp changed?(form) do
    form.any_removed? ||
      do_changed?(form) ||
      Enum.any?(form.forms, fn {_key, forms} ->
        forms
        |> List.wrap()
        |> Enum.any?(&(&1.changed? || &1.added?))
      end)
  end

  defp do_changed?(form) do
    attributes_changed?(form) || arguments_changed?(form)
  end

  defp attributes_changed?(%{source: %Ash.Query{}}), do: false
  defp attributes_changed?(%{source: %Ash.ActionInput{}}), do: false

  defp attributes_changed?(form) do
    changeset = form.source

    changeset.attributes
    |> Map.drop(Enum.map(form.form_keys, &elem(&1, 0)))
    |> Map.delete(:last_editor_save)
    |> Enum.any?(fn {key, value} ->
      original_value =
        case Map.get(changeset.data, key) do
          nil ->
            default(changeset.resource, key)

          value ->
            value
        end

      try do
        Comp.not_equal?(value, original_value)
      rescue
        _ ->
          true
      end
    end)
  end

  @doc false
  def arguments_changed?(form) do
    form = to_form!(form)
    changeset = form.source

    changeset.arguments
    |> Map.drop(Enum.map(form.form_keys, &elem(&1, 0)))
    |> Enum.any?(fn {key, value} ->
      action =
        if is_atom(changeset.action) do
          Ash.Resource.Info.action(changeset.resource, changeset.action)
        else
          changeset.action
        end

      original_value = default_argument(action, key)

      value != original_value
    end)
  end

  # if the value is the same as the default, we don't want to consider it as changed
  defp default_argument(action, key) do
    action.arguments
    |> Enum.find(&(&1.name == key))
    |> case do
      nil ->
        nil

      argument ->
        cond do
          is_nil(argument.default) ->
            nil

          is_function(argument.default) ->
            argument.default.()

          true ->
            argument.default
        end
    end
  end

  defp default(resource, key) do
    attribute = Ash.Resource.Info.attribute(resource, key)

    cond do
      is_nil(attribute.default) ->
        nil

      is_function(attribute.default) ->
        attribute.default.()

      true ->
        attribute.default
    end
  end

  defp apply_or_return(_form, value, function, type, condition \\ true)
  defp apply_or_return(_form, value, _function, _type, false), do: value
  defp apply_or_return(_form, value, nil, _type, _), do: value

  defp apply_or_return(_, value, function, type, _) when is_function(function, 2),
    do: function.(value, type)

  defp apply_or_return(form, value, function, type, _) when is_function(function, 3),
    do: function.(form, value, type)

  @doc """
  Returns the hidden fields for a form as a keyword list
  """
  @spec hidden_fields(t() | Phoenix.HTML.Form.t()) :: Keyword.t()
  def hidden_fields(form) do
    form = to_form!(form)

    hidden =
      if form.type in [:read, :update, :destroy] && form.data do
        pkey =
          form.resource
          |> Ash.Resource.Info.public_attributes()
          |> Enum.filter(& &1.primary_key?)
          |> Enum.reject(&(!&1.public?))
          |> Enum.map(& &1.name)

        form.data
        |> Map.take(pkey)
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

    hidden =
      if form.params["_union_type"] do
        Keyword.put(hidden, :_union_type, form.params["_union_type"])
      else
        hidden
      end

    if form.params["_index"] && form.params["_index"] != "" do
      Keyword.put(hidden, :_index, form.params["_index"])
    else
      hidden
    end
  end

  @doc false
  def update_opts(opts, data \\ nil, params) do
    opts =
      cond do
        is_nil(opts[:updater]) ->
          opts

        is_function(opts[:updater], 1) ->
          opts[:updater].(opts)

        is_function(opts[:updater], 3) ->
          opts[:updater].(opts, data, params)
      end

    opts =
      if Keyword.get(opts, :save_updates?, true) do
        Keyword.delete(opts, :updater)
      else
        opts
      end

    if opts[:forms] do
      Keyword.update!(opts, :forms, fn forms ->
        Enum.map(forms, fn
          {:auto?, value} ->
            {:auto?, value}

          {key, opts} ->
            if opts[:updater] && is_function(opts[:updater], 1) do
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
      Enum.reduce(forms, touched_forms, fn {key, _form_or_forms}, touched_forms ->
        if Map.has_key?(params, to_string(key)) do
          MapSet.put(touched_forms, to_string(key))
        else
          touched_forms
        end
      end)

    touched_forms =
      Enum.reduce(Map.keys(params) -- ["_touched"], touched_forms, &MapSet.put(&2, &1))

    form_touched = params["_touched"]

    if is_binary(form_touched) do
      form_touched
      |> String.split(",")
      |> Enum.concat(Map.keys(params) -- [""])
      |> Enum.reduce(touched_forms, fn key, touched_forms ->
        MapSet.put(touched_forms, key)
      end)
    else
      touched_forms
    end
  end

  defp update_all_forms(form, func) do
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
            {key, update_all_forms(other, func)}
        end
      end)
    end)
  end

  defp do_remove_form(form, [key], trail) when not is_integer(key) do
    unless get_form_key(form.form_keys, key) do
      raise AshPhoenix.Form.NoFormConfigured,
        resource: form.resource,
        action: form.action,
        field: key,
        available: Keyword.keys(form.form_keys || []),
        path: Enum.reverse(trail)
    end

    found_form = form.forms[key]

    any_removed? =
      if found_form && !found_form.added? do
        true
      else
        false
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

    new_forms =
      if (form.form_keys[:type] || :single) == :single do
        Map.put(form.forms, key, nil)
      else
        Map.put(form.forms, key, [])
      end

    %{
      form
      | forms: new_forms,
        any_removed?: form.any_removed? || any_removed?,
        form_keys: new_config,
        touched_forms: MapSet.put(form.touched_forms, to_string(key)),
        opts: Keyword.put(form.opts, :forms, new_config)
    }
  end

  defp do_remove_form(form, [key, i], trail) when is_integer(i) do
    unless get_form_key(form.form_keys, key) do
      raise AshPhoenix.Form.NoFormConfigured,
        resource: form.resource,
        action: form.action,
        field: key,
        available: Keyword.keys(form.form_keys || []),
        path: Enum.reverse(trail)
    end

    new_config = do_remove_data(form, key, i)

    found_form = Enum.at(form.forms[key] || [], i)

    any_removed? =
      if found_form && !found_form.added? do
        true
      else
        false
      end

    new_forms =
      form.forms
      |> Map.put_new(key, [])
      |> Map.update!(key, fn forms ->
        forms
        |> Kernel.||([])
        |> List.delete_at(i)
        |> Enum.with_index()
        |> Enum.map(fn {nested_form, i} ->
          new_name = form.name <> "[#{key}][#{i}]"
          new_id = form.id <> "_#{key}_#{i}"

          if nested_form.name == new_name && nested_form.id == new_id do
            nested_form
          else
            %{
              nested_form
              | name: new_name,
                id: new_id,
                params: add_index(nested_form.params, i, form.opts[:forms][key]),
                forms:
                  replace_form_names(
                    nested_form.forms,
                    {nested_form.name, new_name},
                    {nested_form.id, new_id}
                  )
            }
          end
        end)
      end)

    %{
      form
      | forms: new_forms,
        any_removed?: form.any_removed? || any_removed?,
        touched_forms: MapSet.put(form.touched_forms, to_string(key)),
        form_keys: new_config,
        opts: Keyword.put(form.opts, :forms, new_config)
    }
  end

  defp do_remove_form(form, [key, i | rest], trail) when is_integer(i) do
    unless get_form_key(form.form_keys, key) do
      raise AshPhoenix.Form.NoFormConfigured,
        resource: form.resource,
        action: form.action,
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

    %{form | forms: new_forms, touched_forms: MapSet.put(form.touched_forms, to_string(key))}
  end

  defp do_remove_form(form, [key | rest], trail) do
    unless get_form_key(form.form_keys, key) do
      raise AshPhoenix.Form.NoFormConfigured,
        resource: form.resource,
        action: form.action,
        field: key,
        available: Keyword.keys(form.form_keys || []),
        path: Enum.reverse(trail)
    end

    new_forms =
      form.forms
      |> Map.put_new(key, [])
      |> Map.update!(key, &do_remove_form(&1, rest, [key | trail]))

    %{form | forms: new_forms, touched_forms: MapSet.put(form.touched_forms, to_string(key))}
  end

  defp do_remove_form(_form, path, trail) do
    raise InvalidPath, path: Enum.reverse(trail, path)
  end

  defp replace_form_names(
         forms,
         {original_name, new_name},
         {original_id, new_id}
       ) do
    Map.new(forms || %{}, fn {key, nested} ->
      if is_list(nested) do
        {key,
         Enum.map(
           nested,
           &do_replace_form_names(&1, {original_name, new_name}, {original_id, new_id})
         )}
      else
        {key, do_replace_form_names(nested, {original_name, new_name}, {original_id, new_id})}
      end
    end)
  end

  defp do_replace_form_names(nested, {original_name, new_name}, {original_id, new_id}) do
    new_name = String.replace_leading(nested.name, original_name, new_name)
    new_id = String.replace_leading(nested.id, original_id, new_id)

    %{
      nested
      | name: new_name,
        id: new_id,
        forms: replace_form_names(nested.forms, {nested.name, new_name}, {nested.id, new_id})
    }
  end

  defp get_form_key(form_keys, key) when is_atom(key) do
    form_keys[key]
  end

  defp get_form_key(form_keys, string_key) when is_binary(string_key) do
    Enum.find_value(form_keys, fn {key, value} ->
      if to_string(key) == string_key do
        value
      end
    end)
  end

  defp do_add_form(form, [key, i], opts, trail, transform_errors) when is_integer(i) do
    config =
      get_form_key(form.form_keys, key) ||
        raise AshPhoenix.Form.NoFormConfigured,
          resource: form.resource,
          action: form.action,
          field: key,
          available: Keyword.keys(form.form_keys || []),
          path: Enum.reverse(trail)

    key =
      if is_binary(key) do
        String.to_existing_atom(key)
      else
        key
      end

    {resource, action} = add_form_resource_and_action(opts, config, key, trail)

    data_or_resource =
      if opts[:data] do
        opts[:data]
      else
        resource
      end

    new_form =
      for_action(
        data_or_resource,
        action,
        Keyword.merge(opts[:validate_opts] || [],
          as: form.name <> "[#{key}][#{i}]",
          id: form.id <> "_#{key}_#{i}",
          params: opts[:params] || %{},
          domain: form.domain,
          actor: form.opts[:actor],
          tenant: form.opts[:tenant],
          accessing_from: config[:managed_relationship],
          transform_params: config[:transform_params],
          prepare_source: config[:prepare_source],
          updater: opts[:updater],
          warn_on_unhandled_errors?: form.warn_on_unhandled_errors?,
          forms: config[:forms] || [],
          data: opts[:data],
          transform_errors: transform_errors
        )
      )

    new_forms =
      form.forms
      |> Map.put_new(key, [])
      |> Map.update!(key, fn forms ->
        List.insert_at(
          forms,
          i,
          new_form
        )
        |> Enum.with_index()
        |> Enum.map(fn {nested_form, i} ->
          new_name = form.name <> "[#{key}][#{i}]"
          new_id = form.id <> "_#{key}_#{i}"

          if nested_form.name == new_name && nested_form.id == new_id do
            nested_form
          else
            %{
              nested_form
              | name: new_name,
                id: new_id,
                forms:
                  replace_form_names(
                    nested_form.forms,
                    {nested_form.name, new_name},
                    {nested_form.id, new_id}
                  )
            }
          end
        end)
      end)

    %{form | forms: new_forms, touched_forms: MapSet.put(form.touched_forms, to_string(key))}
  end

  defp do_add_form(form, [key, i | rest], opts, trail, transform_errors) when is_integer(i) do
    unless get_form_key(form.form_keys, key) do
      raise AshPhoenix.Form.NoFormConfigured,
        resource: form.resource,
        action: form.action,
        field: key,
        available: Keyword.keys(form.form_keys || []),
        path: Enum.reverse(trail)
    end

    key =
      if is_binary(key) do
        String.to_existing_atom(key)
      else
        key
      end

    new_forms =
      form.forms
      |> Map.put_new(key, [])
      |> Map.update!(key, fn forms ->
        index =
          if get_form_key(form.form_keys, key)[:sparse?] do
            Enum.find_index(forms, fn form ->
              form.params["_index"] == to_string(i)
            end) || i
          else
            i
          end

        List.update_at(
          forms,
          index,
          &do_add_form(&1, rest, opts, [i, key | trail], transform_errors)
        )
      end)

    %{form | forms: new_forms, touched_forms: MapSet.put(form.touched_forms, to_string(key))}
  end

  defp do_add_form(form, [key], opts, trail, transform_errors) do
    config =
      get_form_key(form.form_keys, key) ||
        raise AshPhoenix.Form.NoFormConfigured,
          resource: form.resource,
          action: form.action,
          field: key,
          available: Keyword.keys(form.form_keys || []),
          path: Enum.reverse(trail)

    key =
      if is_binary(key) do
        String.to_existing_atom(key)
      else
        key
      end

    config = update_opts(config, opts[:data], opts[:params] || %{})

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

        data_or_resource =
          if opts[:data] do
            opts[:data]
          else
            resource
          end

        case config[:type] || :single do
          :single ->
            new_form =
              for_action(
                data_or_resource,
                action,
                Keyword.merge(opts[:validate_opts] || [],
                  as: form.name <> "[#{key}]",
                  id: form.id <> "_#{key}",
                  params: opts[:params] || %{},
                  domain: form.domain,
                  actor: form.opts[:actor],
                  tenant: form.opts[:tenant],
                  accessing_from: config[:managed_relationship],
                  transform_params: config[:transform_params],
                  prepare_source: config[:prepare_source],
                  updater: opts[:updater],
                  warn_on_unhandled_errors?: form.warn_on_unhandled_errors?,
                  forms: config[:forms] || [],
                  data: opts[:data],
                  transform_errors: transform_errors
                )
              )

            %{new_form | added?: true}

          :list ->
            forms = List.wrap(forms)

            index =
              if opts[:prepend] do
                0
              else
                Enum.count(forms)
              end

            new_form =
              for_action(
                data_or_resource,
                action,
                Keyword.merge(opts[:validate_opts] || [],
                  as: form.name <> "[#{key}][#{index}]",
                  id: form.id <> "_#{key}_#{index}",
                  params: opts[:params] || %{},
                  domain: form.domain,
                  actor: form.opts[:actor],
                  tenant: form.opts[:tenant],
                  accessing_from: config[:managed_relationship],
                  transform_params: config[:transform_params],
                  prepare_source: config[:prepare_source],
                  updater: opts[:updater],
                  warn_on_unhandled_errors?: form.warn_on_unhandled_errors?,
                  forms: config[:forms] || [],
                  data: opts[:data],
                  transform_errors: transform_errors
                )
              )

            if opts[:prepend] do
              [%{new_form | added?: true} | forms]
            else
              forms ++ [%{new_form | added?: true}]
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
        opts: Keyword.put(form.opts, :forms, new_config),
        touched_forms: MapSet.put(form.touched_forms, to_string(key))
    }
  end

  defp do_add_form(form, [key | rest], opts, trail, transform_errors) do
    unless get_form_key(form.form_keys, key) do
      raise AshPhoenix.Form.NoFormConfigured,
        resource: form.resource,
        action: form.action,
        field: key,
        available: Keyword.keys(form.form_keys || []),
        path: Enum.reverse(trail)
    end

    key =
      if is_binary(key) do
        String.to_existing_atom(key)
      else
        key
      end

    new_forms =
      Map.update!(form.forms, key, &do_add_form(&1, rest, opts, [key | trail], transform_errors))

    %{form | forms: new_forms, touched_forms: MapSet.put(form.touched_forms, to_string(key))}
  end

  defp do_add_form(_form, path, _opts, trail, _) do
    raise InvalidPath, path: Enum.reverse(trail, List.wrap(path))
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

  defp add_form_resource_and_action(opts, config, key, trail) do
    default =
      cond do
        config[:create_action] && (config[:create_resource] || config[:resource]) ->
          :create

        config[:read_action] && (config[:read_resource] || config[:resource]) ->
          :read

        config[:update_action] && (config[:update_resource] || config[:resource]) ->
          :update

        config[:destroy_action] && (config[:destroy_resource] || config[:resource]) ->
          :destroy

        true ->
          :create
      end

    action =
      case opts[:type] || default do
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
      case opts[:type] || default do
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
        opts =
          case opts[:forms][:auto?] do
            value when is_list(value) ->
              value

            _ ->
              []
          end

        auto =
          resource
          |> AshPhoenix.Form.Auto.auto(action, opts)
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
    else
      false
    end
  end

  defp set_action_errors(form, errors, path \\ []) do
    new_forms =
      form.forms
      |> Map.new(fn {key, forms} ->
        config = get_form_key(form.form_keys, key)

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

    %{
      form
      | submit_errors: transform_errors(form, errors, path, form.form_keys),
        forms: new_forms
    }
  end

  defp synthesize_action_errors(form, trail \\ [], further_errors \\ []) do
    errors =
      form.source.errors
      |> List.wrap()
      |> Enum.flat_map(&expand_error/1)
      |> Enum.map(fn error ->
        %{error | path: trail ++ error.path}
      end)
      |> Enum.filter(&(&1.path == trail))

    new_forms =
      form.forms
      |> Map.new(fn {key, forms} ->
        config = get_form_key(form.form_keys, key)

        new_forms =
          if is_list(forms) do
            forms
            |> Enum.with_index()
            |> Enum.map(fn {form, index} ->
              synthesize_action_errors(
                form,
                trail ++ [config[:for] || key, index],
                errors
              )
            end)
          else
            if forms do
              synthesize_action_errors(forms, trail ++ [config[:for] || key], errors)
            end
          end

        {key, new_forms}
      end)

    %{
      form
      | submit_errors: transform_errors(form, errors ++ further_errors, trail, form.form_keys),
        forms: new_forms
    }
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

  @doc """
  A utility for parsing paths of nested forms in query encoded format.

  For example:

  ```elixir
  parse_path!(form, "post[comments][0][sub_comments][0])

  [:comments, 0, :sub_comments, 0]
  ```
  """
  @spec parse_path!(t() | Phoenix.HTML.Form.t(), path(), opts :: Keyword.t()) ::
          list(atom | integer) | no_return
  def parse_path!(%{name: name} = form, original_path, opts \\ []) do
    form = to_form!(form)

    path =
      if is_binary(original_path) do
        original_path
        |> Plug.Conn.Query.decode()
        |> decoded_to_list()
      else
        List.wrap(original_path)
      end

    {path, last} =
      if opts[:skip_last?] do
        {:lists.droplast(path), List.last(path)}
      else
        {path, nil}
      end

    parsed_path =
      case path do
        [] ->
          []

        [^name | rest] ->
          try do
            do_decode_path(form, original_path, rest, false)
          rescue
            InvalidPath ->
              do_decode_path(form, original_path, [name | rest], false)
          end

        other ->
          try do
            do_decode_path(form, original_path, other, false)
          rescue
            e in InvalidPath ->
              stacktrace = __STACKTRACE__

              try do
                do_decode_path(form, original_path, [name | other], false)
              rescue
                InvalidPath ->
                  reraise e, stacktrace
              end
          end
      end

    if opts[:skip_last?] do
      parsed_path ++ [last]
    else
      parsed_path
    end
  end

  defp do_decode_path(nil, _, _, _), do: nil

  defp do_decode_path(_, _, [], _), do: []

  defp do_decode_path([], original_path, _, _) do
    raise InvalidPath, path: original_path
  end

  defp do_decode_path(forms, original_path, [key | rest], sparse?) when is_list(forms) do
    case parse_int(key) do
      {index, ""} ->
        matching_form =
          if sparse? do
            Enum.find(forms, fn form ->
              form.params["_index"] == to_string(key)
            end)
          else
            Enum.at(forms, index)
          end

        case matching_form do
          nil ->
            raise InvalidPath, path: original_path

          form ->
            case Enum.at(rest, 0) do
              nil ->
                [index | do_decode_path(form, original_path, rest, false)]

              next_key ->
                next_config =
                  Enum.find_value(form.form_keys, fn {search_key, value} ->
                    if to_string(search_key) == next_key do
                      value
                    end
                  end)

                [index | do_decode_path(form, original_path, rest, next_config[:sparse?])]
            end
        end

      _ ->
        raise InvalidPath, path: original_path
    end
  end

  defp do_decode_path(form, original_path, [key | rest], _sparse?) do
    form.form_keys
    |> Enum.find(fn {search_key, _value} ->
      if is_atom(key) do
        search_key == key
      else
        to_string(search_key) == key
      end
    end)
    |> case do
      nil ->
        raise InvalidPath, path: original_path

      {key, config} ->
        if Keyword.get(config, :type, :single) == :single do
          if rest == [] do
            [key]
          else
            [key | do_decode_path(form.forms[key], original_path, rest, config[:sparse?])]
          end
        else
          [key | do_decode_path(form.forms[key] || [], original_path, rest, config[:sparse?])]
        end
    end
  end

  defp parse_int(value) when is_integer(value), do: {value, ""}
  defp parse_int(value) when is_binary(value), do: Integer.parse(value)

  defp decoded_to_list(""), do: []

  defp decoded_to_list(value) do
    {key, rest} = Enum.at(value, 0)

    [key | decoded_to_list(rest)]
  end

  defp handle_forms(
         params,
         form_keys,
         error?,
         domain,
         actor,
         tenant,
         prev_data_trail,
         name,
         id,
         transform_errors,
         warn_on_unhandled_errors?,
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
            domain,
            actor,
            tenant,
            trail,
            prev_data_trail,
            error?,
            name,
            id,
            transform_errors,
            warn_on_unhandled_errors?
          )

        :error ->
          handle_form_without_params(
            forms,
            params,
            opts,
            key,
            domain,
            actor,
            tenant,
            trail,
            prev_data_trail,
            error?,
            name,
            id,
            transform_errors,
            warn_on_unhandled_errors?
          )
      end
    end)
  end

  defp handle_form_without_params(
         forms,
         params,
         opts,
         key,
         domain,
         actor,
         tenant,
         trail,
         prev_data_trail,
         error?,
         name,
         id,
         transform_errors,
         warn_on_unhandled_errors?
       ) do
    if Keyword.has_key?(opts, :data) do
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
        |> case do
          %Ash.Union{value: nil} -> nil
          value -> value
        end

      cond do
        opts[:update_action] ->
          update_action = opts[:update_action]

          if data do
            form_values =
              if (opts[:type] || :single) == :single do
                for_action(data, update_action,
                  domain: domain,
                  actor: actor,
                  tenant: tenant,
                  errors: error?,
                  accessing_from: opts[:managed_relationship],
                  prepare_source: opts[:prepare_source],
                  warn_on_unhandled_errors?: warn_on_unhandled_errors?,
                  transform_params: opts[:transform_params],
                  updater: opts[:updater],
                  prev_data_trail: prev_data_trail,
                  forms: opts[:forms] || [],
                  transform_errors: transform_errors,
                  as: name <> "[#{key}]",
                  id: id <> "_#{key}"
                )
              else
                data
                |> Enum.with_index()
                |> Enum.map(fn {data, index} ->
                  opts = Keyword.put(opts, :data, data)

                  for_action(data, update_action,
                    domain: domain,
                    actor: actor,
                    tenant: tenant,
                    errors: error?,
                    params: add_index(params, index, opts),
                    accessing_from: opts[:managed_relationship],
                    prepare_source: opts[:prepare_source],
                    updater: opts[:updater],
                    warn_on_unhandled_errors?: warn_on_unhandled_errors?,
                    prev_data_trail: prev_data_trail,
                    forms: opts[:forms] || [],
                    transform_params: opts[:transform_params],
                    transform_errors: transform_errors,
                    as: name <> "[#{key}][#{index}]",
                    id: id <> "_#{key}_#{index}"
                  )
                end)
              end

            {Map.put(forms, key, form_values), params}
          else
            {forms, params}
          end

        opts[:read_action] ->
          read_action = opts[:read_action]

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

          data =
            if (opts[:type] || :single) == :single do
              Enum.at(List.wrap(data), 0)
            else
              data
            end

          if data do
            form_values =
              if (opts[:type] || :single) == :single do
                for_action(data, read_action,
                  actor: actor,
                  tenant: tenant,
                  errors: error?,
                  domain: domain,
                  accessing_from: opts[:managed_relationship],
                  prepare_source: opts[:prepare_source],
                  updater: opts[:updater],
                  warn_on_unhandled_errors?: warn_on_unhandled_errors?,
                  transform_params: opts[:transform_params],
                  prev_data_trail: prev_data_trail,
                  forms: opts[:forms] || [],
                  data: data,
                  transform_errors: transform_errors,
                  as: name <> "[#{key}]",
                  id: id <> "_#{key}"
                )
              else
                pkey =
                  case data do
                    [%resource{}] ->
                      if Ash.Resource.Info.resource?(resource) do
                        Ash.Resource.Info.primary_key(resource)
                      else
                        []
                      end

                    _ ->
                      []
                  end

                data
                |> Enum.with_index()
                |> Enum.map(fn {data, index} ->
                  for_action(data, read_action,
                    actor: actor,
                    tenant: tenant,
                    errors: error?,
                    domain: domain,
                    accessing_from: opts[:managed_relationship],
                    prepare_source: opts[:prepare_source],
                    prev_data_trail: prev_data_trail,
                    params: Map.new(pkey, &{to_string(&1), Map.get(data, &1)}),
                    forms: opts[:forms] || [],
                    transform_params: opts[:transform_params],
                    updater: opts[:updater],
                    data: data,
                    transform_errors: transform_errors,
                    as: name <> "[#{key}][#{index}]",
                    id: id <> "_#{key}_#{index}"
                  )
                end)
              end

            {Map.put(forms, key, form_values), params}
          else
            {forms, params}
          end

        true ->
          cond do
            !data ->
              {forms, params}

            opts[:type] == :list ->
              form_values =
                data
                |> List.wrap()
                |> Enum.with_index()
                |> Enum.map(fn {data, index} ->
                  opts = update_opts(opts, data, nil)

                  if opts[:update_action] do
                    for_action(data, opts[:update_action],
                      domain: domain,
                      actor: actor,
                      tenant: tenant,
                      errors: error?,
                      params: add_index(params, index, opts),
                      accessing_from: opts[:managed_relationship],
                      prepare_source: opts[:prepare_source],
                      updater: opts[:updater],
                      warn_on_unhandled_errors?: warn_on_unhandled_errors?,
                      prev_data_trail: prev_data_trail,
                      forms: opts[:forms] || [],
                      transform_params: opts[:transform_params],
                      transform_errors: transform_errors,
                      as: name <> "[#{key}][#{index}]",
                      id: id <> "_#{key}_#{index}"
                    )
                  end
                end)

              {Map.put(forms, key, Enum.filter(form_values, & &1)), params}

            true ->
              opts = update_opts(opts, data, nil)

              form_value =
                if opts[:update_action] do
                  for_action(data, opts[:update_action],
                    domain: domain,
                    actor: actor,
                    tenant: tenant,
                    errors: error?,
                    accessing_from: opts[:managed_relationship],
                    prepare_source: opts[:prepare_source],
                    warn_on_unhandled_errors?: warn_on_unhandled_errors?,
                    transform_params: opts[:transform_params],
                    updater: opts[:updater],
                    prev_data_trail: prev_data_trail,
                    forms: opts[:forms] || [],
                    transform_errors: transform_errors,
                    as: name <> "[#{key}]",
                    id: id <> "_#{key}"
                  )
                end

              {Map.put(forms, key, form_value), params}
          end
      end
    else
      {forms, params}
    end
  end

  defp handle_form_with_params(
         forms,
         params,
         form_params,
         opts,
         key,
         domain,
         actor,
         tenant,
         trail,
         prev_data_trail,
         error?,
         name,
         id,
         transform_errors,
         warn_on_unhandled_errors?
       ) do
    form_values =
      if Keyword.has_key?(opts, :data) do
        handle_form_with_params_and_data(
          opts,
          form_params,
          key,
          domain,
          actor,
          tenant,
          trail,
          prev_data_trail,
          error?,
          name,
          id,
          transform_errors,
          warn_on_unhandled_errors?
        )
      else
        handle_form_with_params_and_no_data(
          opts,
          form_params,
          key,
          domain,
          actor,
          tenant,
          trail,
          prev_data_trail,
          error?,
          name,
          id,
          transform_errors,
          warn_on_unhandled_errors?
        )
      end

    {Map.put(forms, key, form_values), params}
  end

  defp handle_form_with_params_and_no_data(
         opts,
         form_params,
         key,
         domain,
         actor,
         tenant,
         trail,
         prev_data_trail,
         error?,
         name,
         id,
         transform_errors,
         warn_on_unhandled_errors?
       ) do
    opts = update_opts(opts, nil, %{})

    if (opts[:type] || :single) == :single do
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
          actor: actor,
          tenant: tenant,
          params: form_params,
          domain: domain,
          warn_on_unhandled_errors?: warn_on_unhandled_errors?,
          forms: opts[:forms] || [],
          accessing_from: opts[:managed_relationship],
          prepare_source: opts[:prepare_source],
          transform_params: opts[:transform_params],
          updater: opts[:updater],
          errors: error?,
          prev_data_trail: prev_data_trail,
          transform_errors: transform_errors,
          as: name <> "[#{key}]",
          id: id <> "_#{key}"
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
          actor: actor,
          tenant: tenant,
          params: form_params,
          forms: opts[:forms] || [],
          domain: domain,
          accessing_from: opts[:managed_relationship],
          prepare_source: opts[:prepare_source],
          transform_params: opts[:transform_params],
          updater: opts[:updater],
          warn_on_unhandled_errors?: warn_on_unhandled_errors?,
          errors: error?,
          prev_data_trail: prev_data_trail,
          transform_errors: transform_errors,
          as: name <> "[#{key}]",
          id: id <> "_#{key}"
        )
      end
    else
      form_params
      |> indexed_list()
      |> Enum.with_index()
      |> Enum.map(fn {{form_params, original_index}, index} ->
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
            domain: domain,
            actor: actor,
            tenant: tenant,
            params: add_index(form_params, original_index, opts),
            forms: opts[:forms] || [],
            accessing_from: opts[:managed_relationship],
            prepare_source: opts[:prepare_source],
            transform_params: opts[:transform_params],
            updater: opts[:updater],
            warn_on_unhandled_errors?: warn_on_unhandled_errors?,
            errors: error?,
            prev_data_trail: prev_data_trail,
            transform_errors: transform_errors,
            as: name <> "[#{key}][#{index}]",
            id: id <> "_#{key}_#{index}"
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
            domain: domain,
            actor: actor,
            tenant: tenant,
            params: add_index(form_params, original_index, opts),
            forms: opts[:forms] || [],
            accessing_from: opts[:managed_relationship],
            prepare_source: opts[:prepare_source],
            warn_on_unhandled_errors?: warn_on_unhandled_errors?,
            transform_params: opts[:transform_params],
            errors: error?,
            prev_data_trail: prev_data_trail,
            transform_errors: transform_errors,
            updater: opts[:updater],
            as: name <> "[#{key}][#{index}]",
            id: id <> "_#{key}_#{index}"
          )
        end
      end)
    end
  end

  defp handle_form_with_params_and_data(
         opts,
         form_params,
         key,
         domain,
         actor,
         tenant,
         trail,
         prev_data_trail,
         error?,
         name,
         id,
         transform_errors,
         warn_on_unhandled_errors?
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

    if (opts[:type] || :single) == :single do
      opts = update_opts(opts, data, form_params)

      if data do
        case map(form_params)["_form_type"] || "update" do
          "update" ->
            update_action =
              opts[:update_action] ||
                raise AshPhoenix.Form.NoActionConfigured,
                  path: Enum.reverse(trail, [key]),
                  action: :update

            for_action(data, update_action,
              params: form_params,
              domain: domain,
              forms: opts[:forms] || [],
              errors: error?,
              accessing_from: opts[:managed_relationship],
              prepare_source: opts[:prepare_source],
              transform_params: opts[:transform_params],
              warn_on_unhandled_errors?: warn_on_unhandled_errors?,
              prev_data_trail: prev_data_trail,
              transform_errors: transform_errors,
              as: name <> "[#{key}]",
              id: id <> "_#{key}"
            )

          "destroy" ->
            destroy_action =
              opts[:destroy_action] ||
                raise AshPhoenix.Form.NoActionConfigured,
                  path: Enum.reverse(trail, [key]),
                  action: :destroy

            for_action(data, destroy_action,
              actor: actor,
              tenant: tenant,
              params: form_params,
              domain: domain,
              forms: opts[:forms] || [],
              accessing_from: opts[:managed_relationship],
              prepare_source: opts[:prepare_source],
              transform_params: opts[:transform_params],
              updater: opts[:updater],
              errors: error?,
              warn_on_unhandled_errors?: warn_on_unhandled_errors?,
              prev_data_trail: prev_data_trail,
              transform_errors: transform_errors,
              as: name <> "[#{key}]",
              id: id <> "_#{key}"
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
              actor: actor,
              tenant: tenant,
              params: form_params,
              forms: opts[:forms] || [],
              domain: domain,
              accessing_from: opts[:managed_relationship],
              prepare_source: opts[:prepare_source],
              transform_params: opts[:transform_params],
              updater: opts[:updater],
              errors: error?,
              warn_on_unhandled_errors?: warn_on_unhandled_errors?,
              prev_data_trail: prev_data_trail,
              transform_errors: transform_errors,
              as: name <> "[#{key}]",
              id: id <> "_#{key}"
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
              actor: actor,
              tenant: tenant,
              params: form_params,
              forms: opts[:forms] || [],
              domain: domain,
              accessing_from: opts[:managed_relationship],
              prepare_source: opts[:prepare_source],
              transform_params: opts[:transform_params],
              updater: opts[:updater],
              errors: error?,
              warn_on_unhandled_errors?: warn_on_unhandled_errors?,
              prev_data_trail: prev_data_trail,
              transform_errors: transform_errors,
              as: name <> "[#{key}]",
              id: id <> "_#{key}"
            )

          other ->
            raise "unexpected form type for form with no data #{other} with params: #{inspect(form_params)}"
        end
      end
    else
      data = List.wrap(data)

      form_params
      |> indexed_list()
      |> Enum.with_index()
      |> Enum.reduce({[], List.wrap(data)}, fn {{form_params, original_index}, index},
                                               {forms, data} ->
        opts = update_opts(opts, data, form_params)

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
              actor: actor,
              tenant: tenant,
              domain: domain,
              params: add_index(form_params, original_index, opts),
              forms: opts[:forms] || [],
              errors: error?,
              accessing_from: opts[:managed_relationship],
              prepare_source: opts[:prepare_source],
              transform_params: opts[:transform_params],
              updater: opts[:updater],
              warn_on_unhandled_errors?: warn_on_unhandled_errors?,
              prev_data_trail: prev_data_trail,
              transform_errors: transform_errors,
              as: name <> "[#{key}][#{index}]",
              id: id <> "_#{key}_#{index}"
            )

          {[form | forms], data}
        else
          case find_form_match(data, form_params, opts) do
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
                  actor: actor,
                  tenant: tenant,
                  domain: domain,
                  params: add_index(form_params, original_index, opts),
                  forms: opts[:forms] || [],
                  accessing_from: opts[:managed_relationship],
                  prepare_source: opts[:prepare_source],
                  transform_params: opts[:transform_params],
                  updater: opts[:updater],
                  warn_on_unhandled_errors?: warn_on_unhandled_errors?,
                  errors: error?,
                  prev_data_trail: prev_data_trail,
                  transform_errors: transform_errors,
                  as: name <> "[#{key}][#{index}]",
                  id: id <> "_#{key}_#{index}"
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
                    actor: actor,
                    tenant: tenant,
                    domain: domain,
                    params: form_params,
                    forms: opts[:forms] || [],
                    accessing_from: opts[:managed_relationship],
                    prepare_source: opts[:prepare_source],
                    transform_params: opts[:transform_params],
                    updater: opts[:updater],
                    warn_on_unhandled_errors?: warn_on_unhandled_errors?,
                    errors: error?,
                    prev_data_trail: prev_data_trail,
                    transform_errors: transform_errors,
                    as: name <> "[#{key}][#{index}]",
                    id: id <> "_#{key}_#{index}"
                  )
                else
                  update_action =
                    opts[:update_action] ||
                      raise AshPhoenix.Form.NoActionConfigured,
                        path: Enum.reverse(trail, [key]),
                        action: :update

                  for_action(data, update_action,
                    actor: actor,
                    tenant: tenant,
                    domain: domain,
                    params: form_params,
                    forms: opts[:forms] || [],
                    accessing_from: opts[:managed_relationship],
                    prepare_source: opts[:prepare_source],
                    transform_params: opts[:transform_params],
                    updater: opts[:updater],
                    errors: error?,
                    warn_on_unhandled_errors?: warn_on_unhandled_errors?,
                    prev_data_trail: prev_data_trail,
                    transform_errors: transform_errors,
                    as: name <> "[#{key}][#{index}]",
                    id: id <> "_#{key}_#{index}"
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
                  actor: actor,
                  tenant: tenant,
                  domain: domain,
                  params: form_params,
                  forms: opts[:forms] || [],
                  transform_params: opts[:transform_params],
                  accessing_from: opts[:managed_relationship],
                  prepare_source: opts[:prepare_source],
                  warn_on_unhandled_errors?: warn_on_unhandled_errors?,
                  updater: opts[:updater],
                  errors: error?,
                  transform_errors: transform_errors,
                  prev_data_trail: prev_data_trail,
                  as: name <> "[#{key}][#{index}]",
                  id: id <> "_#{key}_#{index}"
                )

              {[form | forms], []}
          end
        end
      end)
      |> elem(0)
      |> Enum.reverse()
    end
  end

  defp find_form_match(data, form_params, opts) do
    match_index =
      if opts[:sparse?] do
        find_resource =
          case data do
            data when data in [nil, []] ->
              nil

            [%resource{} | _] ->
              resource

            %resource{} ->
              resource
          end

        if find_resource do
          pkey_fields = Ash.Resource.Info.primary_key(find_resource)

          pkey =
            Enum.map(pkey_fields, fn field ->
              Ash.Resource.Info.attribute(find_resource, field)
            end)

          casted_pkey =
            Enum.reduce_while(pkey, {:ok, %{}}, fn attribute, {:ok, key_search} ->
              fetched =
                case Map.fetch(form_params, attribute.name) do
                  {:ok, value} ->
                    {:ok, value}

                  :error ->
                    Map.fetch(form_params, to_string(attribute.name))
                end

              case fetched do
                {:ok, value} ->
                  case Ash.Type.cast_input(attribute.type, value, attribute.constraints) do
                    {:ok, value} -> {:cont, {:ok, Map.put(key_search, attribute.name, value)}}
                    _ -> {:halt, :error}
                  end

                :error ->
                  {:halt, :error}
              end
            end)

          case casted_pkey do
            {:ok, empty} when empty == %{} ->
              nil

            {:ok, pkey_search} ->
              Enum.find_index(data, fn data ->
                data && Map.take(data, pkey_fields) == pkey_search
              end)

            :error ->
              nil
          end
        end
      end

    if match_index do
      {match, rest} = List.pop_at(data, match_index)
      [match | rest]
    else
      if opts[:sparse?] do
        [nil | data]
      else
        data
      end
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
    |> Enum.map(fn key ->
      {map[to_string(key)], key}
    end)
    |> Enum.sort_by(fn {params, key} ->
      params["_index"] || key
    end)
  end

  defp indexed_list(other) do
    other
    |> List.wrap()
    |> Enum.with_index()
  end

  defp fetch_key(params, key) do
    case Map.fetch(params, key) do
      {:ok, value} -> {:ok, value}
      :error -> Map.fetch(params, to_string(key))
    end
  end

  defp form_for_method(:create), do: "post"
  defp form_for_method(_), do: "put"

  defp exclude_empty_fields(params, []) do
    params
  end

  defp exclude_empty_fields(params, _) when params == %{} do
    params
  end

  defp exclude_empty_fields(params, [unset_key | rest]) when is_atom(unset_key) do
    {_, new} =
      Map.get_and_update(params, to_string(unset_key), fn
        "" -> :pop
        nil -> :pop
        value -> {value, value}
      end)

    exclude_empty_fields(new, rest)
  end

  defp exclude_empty_fields(params, [{nested_type, nested_keys} | rest]) do
    {_, new} =
      Map.get_and_update(params, to_string(nested_type), fn
        nil ->
          :pop

        map ->
          {map, exclude_empty_fields(map, nested_keys)}
      end)

    exclude_empty_fields(new, rest)
  end

  defimpl Phoenix.HTML.FormData do
    import AshPhoenix.FormData.Helpers

    @impl true
    def to_form(form, opts) do
      hidden = AshPhoenix.Form.hidden_fields(form)

      errors =
        if form.errors do
          if form.just_submitted? do
            form.submit_errors
          else
            transform_errors(form, form.source.errors, [], form.form_keys)
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
        params: form_params(form),
        hidden: hidden,
        options: Keyword.put_new(opts, :method, form.method)
      }
    end

    defp form_params(%{params: params}) when not is_nil(params), do: params
    defp form_params(_), do: nil

    @impl true
    def to_form(form, _phoenix_form, field, opts) do
      unless Keyword.has_key?(form.form_keys, field) do
        raise AshPhoenix.Form.NoFormConfigured,
          resource: form.resource,
          action: form.action,
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
    def input_value(form, phoenix_form, field) do
      if is_atom(field) and form.form_keys[field] do
        List.wrap(to_form(form, phoenix_form, field, []))
      else
        AshPhoenix.Form.value(form, field)
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

    def input_validations(%{source: %Ash.ActionInput{} = action_input}, _, field) do
      argument = get_argument(action_input.action, field)

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
  end

  defp drop_form_opts(opts) do
    Keyword.drop(opts, [
      :forms,
      :transform_errors,
      :errors,
      :id,
      :method,
      :for,
      :as,
      :transform_params,
      :prepare_params,
      :prepare_source,
      :warn_on_unhandled_errors?
    ])
  end
end
