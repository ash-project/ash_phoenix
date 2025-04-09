defmodule AshPhoenix.Transformers.AddFormCodeInterfaces do
  @moduledoc false

  use Spark.Dsl.Transformer

  def after?(_), do: true

  def transform(dsl_state) do
    case Ash.Domain.Info.resource_references(dsl_state) do
      [] ->
        resource = Spark.Dsl.Transformer.get_persisted(dsl_state, :module)

        dsl_state
        |> Ash.Resource.Info.interfaces()
        |> Enum.filter(&match?(%Ash.Resource.Interface{}, &1))
        |> Enum.uniq_by(& &1.name)
        |> Enum.reduce(dsl_state, &add_form_interface(&1, &2, resource, true))
        |> then(&{:ok, &1})

      references ->
        references
        |> Enum.reduce(dsl_state, fn reference, dsl_state ->
          reference.definitions
          |> Enum.filter(&match?(%Ash.Resource.Interface{}, &1))
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

    form = AshPhoenix.Info.form(dsl_state, interface.name)
    args = (form && form.args) || []

    arg_vars_function =
      Enum.map(args, fn
        {:optional, key} ->
          default = Ash.CodeInterface.default_value(resource, action, key)
          {:\\, [], [{key, [], Elixir}, default]}

        key ->
          {key, [], Elixir}
      end)

    arg_names =
      Enum.map(args, fn
        {:optional, name} ->
          name

        name ->
          name
      end)

    delete = Enum.flat_map(arg_names, &[&1, to_string(&1)])

    {private_args, params} =
      Enum.split_with(arg_names, fn arg ->
        Enum.any?(action.arguments, &(&1.name == arg && !&1.public?))
      end)

    merge_params = {:%{}, [], Enum.map(params, &{to_string(&1), {&1, [], Elixir}})}
    private_args_merge = {:%{}, [], Enum.map(private_args, &{&1, {&1, [], Elixir}})}

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

            def unquote(name)(record, unquote_splicing(arg_vars_function), form_opts \\ []) do
              form_opts =
                form_opts
                |> unquote(__MODULE__).merge_and_drop_params(
                  unquote(merge_params),
                  unquote(delete)
                )
                |> unquote(__MODULE__).set_private_arguments(unquote(private_args_merge))

              AshPhoenix.Form.for_action(record, unquote(action.name), form_opts)
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
            def unquote(name)(unquote_splicing(arg_vars_function), form_opts \\ []) do
              form_opts =
                form_opts
                |> unquote(__MODULE__).merge_and_drop_params(
                  unquote(merge_params),
                  unquote(delete)
                )
                |> unquote(__MODULE__).set_private_arguments(unquote(private_args_merge))

              AshPhoenix.Form.for_action(unquote(resource), unquote(action.name), form_opts)
              |> Map.put(:params, unquote(merge_params))
              |> Map.put(:raw_params, unquote(merge_params))
            end
          end

        Spark.Dsl.Transformer.eval(dsl_state, [], define)
    end
  end

  @doc false
  def merge_and_drop_params(opts, merge_params, delete)
      when merge_params == %{} and delete == [] do
    opts
  end

  def merge_and_drop_params(opts, merge_params, delete) do
    opts
    |> Keyword.update(:params, merge_params, fn existing_params ->
      existing_params
      |> Kernel.||(%{})
      |> Map.delete(delete)
      |> Map.merge(merge_params)
    end)
    |> Keyword.update(
      :transform_params,
      fn _form, params, _ ->
        params
        |> Map.drop(delete)
        |> Map.merge(merge_params)
      end,
      fn existing ->
        existing =
          existing ||
            fn _, params, _ ->
              params
            end

        fn form, params, type ->
          params =
            params
            |> Map.drop(delete)
            |> Map.merge(merge_params)

          if is_function(existing, 2) do
            existing.(params, type)
          else
            existing.(form, params, type)
          end
        end
      end
    )
  end

  @doc false
  def set_private_arguments(opts, empty) when empty == %{} do
    opts
  end

  def set_private_arguments(opts, private_args_merge) do
    Keyword.update(
      opts,
      :private_arguments,
      private_args_merge,
      &Map.merge(&1 || %{}, private_args_merge)
    )
  end
end
