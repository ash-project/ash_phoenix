defmodule AshPhoenix do
  @moduledoc """
  An extension to add form builders to the code interface.

  There is currently no DSL for this extension.

  This defines a `form_to_<name>` function for each code interface
  function. Positional arguments are ignored, given that in forms,
  all input typically comes from the `params` map.

  The generated function passes all options through to
  `AshPhoenix.Form.for_action/3`

  Update and destroy actions take the record being updated/destroyed
  as the first argument.

  For example, given this code interface definition on a domain
  called `MyApp.Accounts`:

  ```elixir
  resources do
    resource MyApp.Accounts.User do
      define :register_with_password, args: [:email, :password]
      define :update_user, action: :update, args: [:email, :password]
    end
  end
  ```

  Adding the `AshPhoenix` extension would define 
  `form_to_register_with_password/2`.

  ## Usage

  Without options:

  ```elixir
  MyApp.Accounts.form_to_register_with_password()
  #=> %AshPhoenix.Form{}
  ```

  With options:

  ```elixir
  MyApp.Accounts.form_to_register_with_password(params: %{"email" => "placeholder@email"})
  #=> %AshPhoenix.Form{}
  ```

  With 

  ```elixir
  MyApp.Accounts.form_to_update_user(params: %{"email" => "placeholder@email"})
  #=> %AshPhoenix.Form{}
  ```
  """

  defmodule AddFormCodeInterfaces do
    @moduledoc false

    use Spark.Dsl.Transformer

    def after?(_), do: true

    def transform(dsl_state) do
      case Ash.Domain.Info.resource_references(dsl_state) do
        [] ->
          resource = Spark.Dsl.Transformer.get_persisted(dsl_state, :module)

          dsl_state
          |> Ash.Resource.Info.interfaces()
          |> Enum.uniq_by(& &1.name)
          |> Enum.reduce(dsl_state, &add_form_interface(&1, &2, resource, true))
          |> then(&{:ok, &1})

        references ->
          references
          |> Enum.reduce(dsl_state, fn reference, dsl_state ->
            reference.definitions
            |> Enum.uniq_by(& &1.name)
            |> Enum.reduce(dsl_state, &add_form_interface(&1, &2, reference.resource))
          end)
          |> then(&{:ok, &1})
      end
    end

    # sobelow_skip ["DOS.BinToAtom"]
    defp add_form_interface(interface, dsl_state, resource, resource? \\ false) do
      name = :"form_to_#{interface.name}"

      action =
        if resource? do
          Ash.Resource.Info.action(dsl_state, interface.action || interface.name)
        else
          Ash.Resource.Info.action(resource, interface.action || interface.name)
        end

      cond do
        !action ->
          dsl_state

        action.type in [:update, :destroy] and interface.require_reference? ->
          define =
            quote do
              @doc """
                   #{unquote(action.description) || "Creates a form for the #{unquote(action.name)} action on #{unquote(inspect(resource))}."}

                   ## Options

                   #{Spark.Options.docs(AshPhoenix.Form.for_opts())}

                   Any *additional* options will be passed to the underlying call to build the source, i.e
                   `Ash.ActionInput.for_action/4`, or `Ash.Changeset.for_*`. This means you can set things
                   like the tenant/actor. These will be retained, and provided again when 
                   `Form.submit/3` is called.

                   ## Nested Form Options

                   #{Spark.Options.docs(AshPhoenix.Form.nested_form_opts())}
                   """
                   |> Ash.CodeInterface.trim_double_newlines()

              def unquote(name)(record, opts \\ []) do
                AshPhoenix.Form.for_action(record, unquote(action.name), opts)
              end
            end

          Spark.Dsl.Transformer.eval(dsl_state, [], define)

        true ->
          define =
            quote do
              @doc """
                   #{unquote(action.description) || "Creates a form for the #{unquote(action.name)} action on #{unquote(inspect(resource))}."}

                   ## Options

                   #{Spark.Options.docs(AshPhoenix.Form.for_opts())}

                   Any *additional* options will be passed to the underlying call to build the source, i.e
                   `Ash.ActionInput.for_action/4`, or `Ash.Changeset.for_*`. This means you can set things
                   like the tenant/actor. These will be retained, and provided again when 
                   `Form.submit/3` is called.

                   ## Nested Form Options

                   #{Spark.Options.docs(AshPhoenix.Form.nested_form_opts())}
                   """
                   |> Ash.CodeInterface.trim_double_newlines()
              def unquote(name)(opts \\ []) do
                AshPhoenix.Form.for_action(unquote(resource), unquote(action.name), opts)
              end
            end

          Spark.Dsl.Transformer.eval(dsl_state, [], define)
      end
    end
  end

  use Spark.Dsl.Extension, transformers: [AddFormCodeInterfaces]
end
