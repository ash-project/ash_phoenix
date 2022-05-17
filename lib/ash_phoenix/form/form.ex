defmodule AshPhoenix.Form do
  @moduledoc """
  A module to allow you to fluidly use resources with phoenix forms.

  The general workflow is, with either liveview or phoenix forms:

  1. Create a form with `AshPhoenix.Form`
  2. Render that form with Phoenix's `form_for` (or, if using surface, <Form>)
  3. To validate the form (e.g with `on-change` for liveview), pass the input to `AshPhoenix.Form.validate(form, params)`
  4. On form submission, pass the input to `AshPhoenix.Form.validate(form, params)` and then use `AshPhoenix.Form.submit(form, ApiModule)`

  ### Working with related data
  If your resource action accepts related data, (for example a managed relationship argument, or an embedded resource attribute), you can
  use Phoenix's `inputs_for` for that field, *but* you must do one of two things:

  1. Tell AshPhoenix.Form to automatically derive this behavior from your action, for example:

  ```elixir
  form =
    user
    |> AshPhoenix.Form.for_update(:update,
      api: MyApi,
      forms: [auto?: true]
      ])
  ```

  2. Explicitly configure the behavior of it using the `forms` option. See `for_create/3` for more.

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

      REMEMBER: You need to use `hidden_inputs_for` (or `HiddenInputs` if using surface) for the id to be automatically placed into the form.
      """
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

    name = opts[:as] || "form"
    id = opts[:id] || opts[:as] || "form"

    {forms, params} =
      handle_forms(
        opts[:params] || %{},
        opts[:forms] || [],
        !!opts[:errors],
        [],
        name,
        id,
        opts[:transform_errors]
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
      id: id,
      touched_forms: touched_forms(forms, params, opts),
      method: opts[:method] || form_for_method(:create),
      opts: opts,
      source:
        resource
        |> Ash.Changeset.new()
        |> Ash.Changeset.for_create(
          action,
          params,
          changeset_opts
        )
    }
    |> set_changed?()
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
        name,
        id,
        opts[:transform_errors],
        [data]
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
      touched_forms: touched_forms(forms, params, opts),
      opts: opts,
      id: id,
      name: name,
      source:
        data
        |> Ash.Changeset.new()
        |> Ash.Changeset.for_update(
          action,
          params,
          changeset_opts
        )
    }
    |> set_changed?()
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
        name,
        id,
        opts[:transform_errors],
        [data]
      )

    %__MODULE__{
      resource: resource,
      data: data,
      action: action,
      type: :destroy,
      params: params,
      errors: opts[:errors],
      transform_errors: opts[:transform_errors],
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
        |> Ash.Changeset.for_destroy(
          action,
          params,
          changeset_opts
        )
    }
    |> set_changed?()
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
        opts[:transform_errors]
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
      data: opts[:data],
      params: params,
      errors: opts[:errors],
      transform_errors: opts[:transform_errors],
      name: name,
      forms: forms,
      form_keys: List.wrap(opts[:forms]),
      id: id,
      api: opts[:api],
      method: opts[:method] || form_for_method(:create),
      opts: opts,
      touched_forms: touched_forms(forms, params, opts),
      source:
        Ash.Query.for_read(
          resource,
          action,
          params || %{},
          query_opts
        )
        |> add_errors_for_unhandled_params(params)
    }
    |> set_changed?()
    |> set_validity()
  end

  defp add_errors_for_unhandled_params(%{action: nil} = query, _params), do: query

  defp add_errors_for_unhandled_params(query, params) do
    arguments = Enum.map(query.action.arguments, &to_string(&1.name))

    remaining_params = Map.drop(params, arguments)

    Enum.reduce(remaining_params, query, fn {key, value}, query ->
      attribute = Ash.Resource.Info.public_attribute(query.resource, key)

      if attribute do
        case Ash.Changeset.cast_input(attribute.type, value, attribute.constraints, query) do
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
              |> Ash.Changeset.error_to_exception_opts(attribute)
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
    opts = validate_opts_with_extra_keys(opts, @validate_opts)

    matcher =
      opts[:matcher] ||
        fn nested_form, _params, root_form, key, index ->
          nested_form.id == root_form.id <> "_#{key}_#{index}"
        end

    {forms, params} =
      validate_nested_forms(
        form,
        new_params || %{},
        !!opts[:errors],
        opts[:prev_data_trail] || [],
        matcher
      )

    if params == form.params && !!opts[:errors] == form.errors do
      %{
        form
        | forms: forms,
          submit_errors: nil,
          touched_forms: touched_forms(forms, params, touched_forms: form.touched_forms)
      }
      |> set_validity()
      |> set_changed?()
      |> update_all_forms(fn form ->
        %{form | just_submitted?: false}
      end)
    else
      source_opts =
        Keyword.drop(form.opts, [
          :forms,
          :transform_errors,
          :errors,
          :id,
          :method,
          :for,
          :as
        ])

      new_source =
        case form.type do
          :create ->
            form.resource
            |> Ash.Changeset.new()
            |> Ash.Changeset.for_create(
              form.action,
              params,
              source_opts
            )

          :update ->
            form.data
            |> Ash.Changeset.new()
            |> Ash.Changeset.for_update(
              form.action,
              params,
              source_opts
            )

          :destroy ->
            form.data
            |> Ash.Changeset.new()
            |> Ash.Changeset.for_destroy(
              form.action,
              params,
              source_opts
            )

          :read ->
            Ash.Query.for_read(
              form.resource,
              form.action,
              params,
              source_opts
            )
            |> add_errors_for_unhandled_params(params)
        end

      %{
        form
        | source: new_source,
          forms: forms,
          params: params,
          errors: !!opts[:errors],
          submit_errors: nil,
          touched_forms: touched_forms(forms, params, touched_forms: form.touched_forms)
      }
      |> set_validity()
      |> set_changed?()
      |> update_all_forms(fn form ->
        %{form | just_submitted?: false}
      end)
    end
  end

  defp validate_nested_forms(
         form,
         params,
         errors?,
         prev_data_trail,
         matcher,
         trail \\ []
       ) do
    Enum.reduce(form.form_keys, {%{}, params}, fn {key, opts}, {forms, params} ->
      forms =
        case fetch_key(params, opts[:as] || key) do
          {:ok, form_params} when form_params != nil ->
            if opts[:type] == :list do
              form_params =
                if is_list(form_params) do
                  form_params
                  |> Enum.with_index()
                  |> Map.new(fn {params, i} ->
                    {to_string(i), params}
                  end)
                else
                  form_params || %{}
                end

              new_forms =
                Enum.reduce(form_params, forms, fn {index, params}, forms ->
                  case Enum.find(form.forms[key] || [], &matcher.(&1, params, form, key, index)) do
                    nil ->
                      create_action =
                        opts[:create_action] ||
                          raise AshPhoenix.Form.NoActionConfigured,
                            path: form.name <> "[#{key}][#{index}]",
                            action: :create

                      resource =
                        opts[:create_resource] || opts[:resource] ||
                          raise AshPhoenix.Form.NoResourceConfigured,
                            path: Enum.reverse(trail, [key])

                      new_form =
                        for_action(resource, create_action,
                          params: params,
                          forms: opts[:forms] || [],
                          errors: errors?,
                          prev_data_trail: prev_data_trail,
                          transform_errors: form.transform_errors,
                          as: form.name <> "[#{key}][#{index}]",
                          id: form.id <> "_#{key}_#{index}"
                        )

                      Map.update(forms, key, [new_form], &(&1 ++ [new_form]))

                    matching_form ->
                      validated =
                        validate(matching_form, params,
                          errors?: errors?,
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

              if Map.has_key?(new_forms, opts[:as] || key) do
                Map.update!(new_forms, opts[:as] || key, fn nested_forms ->
                  Enum.sort_by(nested_forms, & &1.id)
                end)
              else
                new_forms
              end
            else
              if form.forms[key] do
                new_form =
                  validate(form.forms[key], form_params, errors?: errors?, matcher: matcher)

                Map.put(forms, key, new_form)
              else
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
                    params: form_params,
                    forms: opts[:forms] || [],
                    errors: errors?,
                    prev_data_trail: prev_data_trail,
                    transform_errors: form.transform_errors,
                    as: form.name <> "[#{key}]",
                    id: form.id <> "_#{key}"
                  )

                Map.put(forms, key, new_form)
              end
            end

          _ ->
            case opts[:type] do
              :list ->
                Map.put(forms, key, [])

              _ ->
                Map.put(forms, key, nil)
            end
        end

      {forms, Map.delete(params, [key, to_string(key)])}
    end)
  end

  @submit_opts [
    force?: [
      type: :boolean,
      default: false,
      doc: "Submit the form even if it is invalid in its current state."
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
        validate(
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

      case Ash.Api.resource(form.api, form.resource) do
        {:ok, _} ->
          :ok

        {:error, error} ->
          raise error
      end

      {original_changeset_or_query, result} =
        case form.type do
          :create ->
            form.resource
            |> Ash.Changeset.for_create(
              form.source.action.name,
              opts[:override_params] || params(form),
              changeset_opts
            )
            |> before_submit.()
            |> with_changeset(&form.api.create/1)

          :update ->
            form.original_data
            |> Ash.Changeset.for_update(
              form.source.action.name,
              opts[:override_params] || params(form),
              changeset_opts
            )
            |> before_submit.()
            |> with_changeset(&form.api.update/1)

          :destroy ->
            form.original_data
            |> Ash.Changeset.for_destroy(
              form.source.action.name,
              opts[:override_params] || params(form),
              changeset_opts
            )
            |> before_submit.()
            |> form.api.destroy()
            |> with_changeset(&form.api.update/1)

          :read ->
            form.resource
            |> Ash.Query.for_read(
              form.source.action.name,
              opts[:override_params] || params(form),
              changeset_opts
            )
            |> before_submit.()
            |> with_changeset(&form.api.read/1)
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
            query = %{(query || original_changeset_or_query) | errors: []}

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
             end)
             |> set_changed?()}
          end

        {:error, %{changeset: changeset} = error} when form.type != :read ->
          if opts[:raise?] do
            raise Ash.Error.to_error_class(changeset.errors, changeset: changeset)
          else
            changeset = %{(changeset || original_changeset_or_query) | errors: []}

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

  @spec has_form?(t(), list(atom | integer) | String.t()) :: boolean
  def has_form?(form, path) do
    not is_nil(get_form(form, path))
  rescue
    InvalidPath ->
      false
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
          ([{atom, {String.t(), Keyword.t()}}]
           | [String.t()]
           | [{atom, String.t()}])
          | %{
              list => [{atom, {String.t(), Keyword.t()}}] | [String.t()] | [{atom, String.t()}]
            }
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
    # These options aren't documented because they are still experimental
    hidden? = opts[:hidden?] || false
    indexer = opts[:indexer]
    indexed_lists? = opts[:indexed_lists?] || not is_nil(indexer) || false
    transform = opts[:transform]
    produce = opts[:produce]
    only_touched? = Keyword.get(opts, :only_touched?, true)

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

    untransformed_params =
      form.form_keys
      |> only_touched(form, only_touched?)
      |> Enum.reduce(params, fn {key, config}, params ->
        for_name = to_string(config[:for] || key)

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
                Map.put(params, for_name, nested_params)
              end
            else
              if is_touched?(form, key) do
                Map.put(params, for_name, nil)
              else
                params
              end
            end

          :list ->
            if form.forms[key] do
              if indexed_lists? do
                params
                |> Map.put_new(for_name, %{})
                |> Map.update!(for_name, fn current ->
                  if indexer do
                    Enum.reduce(form.forms[key], current, fn form, current ->
                      Map.put(current, indexer.(form), params(form, opts))
                    end)
                  else
                    max =
                      current
                      |> Map.keys()
                      |> Enum.map(&String.to_integer/1)
                      |> Enum.max(fn -> -1 end)

                    form.forms[key]
                    |> Enum.reduce({current, max + 1}, fn form, {current, i} ->
                      {Map.put(current, to_string(i), params(form, opts)), i + 1}
                    end)
                    |> elem(0)
                  end
                end)
              else
                params
                |> Map.put_new(for_name, [])
                |> Map.update!(for_name, fn current ->
                  current ++ Enum.map(form.forms[key] || [], &params(&1, opts))
                end)
              end
            else
              if is_touched?(form, key) do
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

    if transform do
      Map.new(with_produced_params, transform)
    else
      with_produced_params
    end
  end

  defp only_touched(form_keys, true, form) do
    Enum.filter(form_keys, fn {key, _} ->
      is_touched?(form, key)
    end)
  end

  defp only_touched(form_keys, _, _), do: form_keys

  defp is_touched?(form, key), do: MapSet.member?(form.touched_forms, to_string(key))

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
    type: [
      type: {:one_of, [:read, :create]},
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

    form =
      if is_binary(path) do
        path = parse_path!(form, path)
        do_add_form(form, path, opts, [], form.transform_errors)
      else
        path = List.wrap(path)
        do_add_form(form, path, opts, [], form.transform_errors)
      end

    form = set_changed?(form)

    if opts[:validate?] do
      validate(form, params(form))
    else
      form
    end
  end

  @remove_form_opts [
    validate?: [
      type: :boolean,
      default: true,
      doc: "Validates the new full form."
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
  """
  def remove_form(form, path, opts \\ []) do
    opts = Ash.OptionsHelpers.validate!(opts, @remove_form_opts)

    if has_form?(form, path) do
      form =
        if is_binary(path) do
          path = parse_path!(form, path)
          do_remove_form(form, path, [])
        else
          path = List.wrap(path)
          do_remove_form(form, path, [])
        end

      form = set_changed?(form)

      if opts[:validate?] do
        validate(form, params(form))
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
      is_changed?(form) ||
      Enum.any?(form.forms, fn {_key, forms} ->
        forms
        |> List.wrap()
        |> Enum.any?(&(&1.changed? || &1.added?))
      end)
  end

  defp is_changed?(form) do
    attributes_changed?(form) || arguments_changed?(form)
  end

  defp attributes_changed?(%{source: %Ash.Query{}}), do: false

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

      Comp.not_equal?(value, original_value)
    end)
  end

  def arguments_changed?(form) do
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

    new_forms = Map.put(form.forms, key, nil)

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
    unless form.form_keys[key] do
      raise AshPhoenix.Form.NoFormConfigured,
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
          %{nested_form | name: form.name <> "[#{key}][#{i}]", id: form.id <> "_#{key}_#{i}"}
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

    %{form | forms: new_forms, touched_forms: MapSet.put(form.touched_forms, to_string(key))}
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

    %{form | forms: new_forms, touched_forms: MapSet.put(form.touched_forms, to_string(key))}
  end

  defp do_remove_form(_form, path, trail) do
    raise InvalidPath, path: Enum.reverse(trail, path)
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
        index =
          if form.form_keys[key][:sparse?] do
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

    %{form | forms: new_forms, touched_forms: MapSet.put(form.touched_forms, key)}
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

        data_or_resource =
          if opts[:data] do
            opts[:data]
          else
            resource
          end

        new_form =
          for_action(data_or_resource, action,
            params: opts[:params] || %{},
            forms: config[:forms] || [],
            data: opts[:data],
            transform_errors: transform_errors
          )

        case config[:type] || :single do
          :single ->
            %{new_form | name: form.name <> "[#{key}]", id: form.id <> "_#{key}", added?: true}

          :list ->
            forms = List.wrap(forms)

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
        touched_forms: MapSet.put(form.touched_forms, key)
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

    %{form | forms: new_forms, touched_forms: MapSet.put(form.touched_forms, key)}
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
    else
      false
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

    %{
      form
      | submit_errors: transform_errors(form, errors, path, form.form_keys),
        forms: new_forms
    }
  end

  defp synthesize_action_errors(form, trail \\ []) do
    new_forms =
      form.forms
      |> Map.new(fn {key, forms} ->
        new_forms =
          if is_list(forms) do
            Enum.map(forms, fn form ->
              synthesize_action_errors(form, [key | trail])
            end)
          else
            if forms do
              synthesize_action_errors(forms, [key | trail])
            end
          end

        {key, new_forms}
      end)

    errors =
      form.source.errors
      |> List.wrap()
      |> Enum.flat_map(&expand_error/1)

    %{form | submit_errors: transform_errors(form, errors, [], form.form_keys), forms: new_forms}
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
        do_decode_path(form, original_path, rest, false)

      _other ->
        raise InvalidPath, path: original_path
    end
  end

  defp do_decode_path(nil, _, _, _), do: nil

  defp do_decode_path(_, _, [], _), do: []

  defp do_decode_path([], original_path, _, _) do
    raise "Invalid Path: #{original_path}"
  end

  defp do_decode_path(forms, original_path, [key | rest], sparse?) when is_list(forms) do
    case Integer.parse(key) do
      {index, ""} ->
        matching_form =
          if sparse? do
            Enum.find(forms, fn form ->
              form.params["_index"] == key
            end)
          else
            Enum.at(forms, index)
          end

        case matching_form do
          nil ->
            raise "Invalid Path: #{original_path}"

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
        raise "Invalid Path: #{original_path}"
    end
  end

  defp do_decode_path(form, original_path, [key | rest], _sparse?) do
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
         name,
         id,
         transform_errors,
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
            name,
            id,
            transform_errors
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
            name,
            id,
            transform_errors
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
         name,
         id,
         transform_errors
       ) do
    if Keyword.has_key?(opts, :data) do
      cond do
        opts[:update_action] ->
          update_action = opts[:update_action]

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
            form_values =
              if (opts[:type] || :single) == :single do
                for_action(data, update_action,
                  errors: error?,
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
                  for_action(data, update_action,
                    errors: error?,
                    prev_data_trail: prev_data_trail,
                    forms: opts[:forms] || [],
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

          if data do
            form_values =
              if (opts[:type] || :single) == :single do
                pkey = Ash.Resource.Info.primary_key(data.__struct__)

                for_action(data, read_action,
                  errors: error?,
                  params: Map.new(pkey, &{to_string(&1), Map.get(data, &1)}),
                  prev_data_trail: prev_data_trail,
                  forms: opts[:forms] || [],
                  data: data,
                  transform_errors: transform_errors,
                  as: name <> "[#{key}]",
                  id: id <> "_#{key}"
                )
              else
                pkey =
                  unless Enum.empty?(data) do
                    Ash.Resource.Info.primary_key(Enum.at(data, 0).__struct__)
                  end

                data
                |> Enum.with_index()
                |> Enum.map(fn {data, index} ->
                  for_action(data, read_action,
                    errors: error?,
                    prev_data_trail: prev_data_trail,
                    params: Map.new(pkey, &{to_string(&1), Map.get(data, &1)}),
                    forms: opts[:forms] || [],
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
         trail,
         prev_data_trail,
         error?,
         name,
         id,
         transform_errors
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
          name,
          id,
          transform_errors
        )
      else
        handle_form_with_params_and_no_data(
          opts,
          form_params,
          key,
          trail,
          prev_data_trail,
          error?,
          name,
          id,
          transform_errors
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
         name,
         id,
         transform_errors
       ) do
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
          params: form_params,
          forms: opts[:forms] || [],
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
          params: form_params,
          forms: opts[:forms] || [],
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
            params: add_index(form_params, original_index, opts),
            forms: opts[:forms] || [],
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
            params: add_index(form_params, original_index, opts),
            forms: opts[:forms] || [],
            errors: error?,
            prev_data_trail: prev_data_trail,
            transform_errors: transform_errors,
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
         trail,
         prev_data_trail,
         error?,
         name,
         id,
         transform_errors
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
              forms: opts[:forms] || [],
              errors: error?,
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
              params: form_params,
              forms: opts[:forms] || [],
              errors: error?,
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
              params: form_params,
              forms: opts[:forms] || [],
              errors: error?,
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
              params: form_params,
              forms: opts[:forms] || [],
              errors: error?,
              prev_data_trail: prev_data_trail,
              transform_errors: transform_errors,
              as: name <> "[#{key}]",
              id: id <> "_#{key}"
            )
        end
      end
    else
      data = List.wrap(data)

      form_params
      |> indexed_list()
      |> Enum.with_index()
      |> Enum.reduce({[], List.wrap(data)}, fn {{form_params, original_index}, index},
                                               {forms, data} ->
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
              params: add_index(form_params, original_index, opts),
              forms: opts[:forms] || [],
              errors: error?,
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
                  params: add_index(form_params, original_index, opts),
                  forms: opts[:forms] || [],
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
                    params: form_params,
                    forms: opts[:forms] || [],
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
                    params: form_params,
                    forms: opts[:forms] || [],
                    errors: error?,
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
                  params: form_params,
                  forms: opts[:forms] || [],
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

  defimpl Phoenix.HTML.FormData do
    import AshPhoenix.FormData.Helpers

    @impl true
    def to_form(form, opts) do
      hidden =
        if form.type in [:read, :update, :destroy] && form.data do
          pkey =
            form.resource
            |> Ash.Resource.Info.public_attributes()
            |> Enum.filter(& &1.primary_key?)
            |> Enum.reject(& &1.private?)
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
        if form.params["_index"] && form.params["_index"] != "" do
          Keyword.put(hidden, :_index, form.params["_index"])
        else
          hidden
        end

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

    def input_value(%{source: %Ash.Query{} = query, data: data}, _form, field) do
      case Ash.Query.fetch_argument(query, field) do
        {:ok, value} ->
          value

        :error ->
          case Map.fetch(query.params, to_string(field)) do
            {:ok, value} ->
              value

            :error ->
              if data do
                Map.get(data, field)
              end
          end
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
