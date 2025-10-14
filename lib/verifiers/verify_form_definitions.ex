# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs.contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPhoenix.Verifiers.VerifyFormDefinitions do
  @moduledoc false
  use Spark.Dsl.Verifier

  def verify(dsl) do
    module = Spark.Dsl.Verifier.get_persisted(dsl, :module)

    dsl
    |> AshPhoenix.Info.forms()
    |> Enum.each(fn form ->
      case get_interface(dsl, form) do
        {:ok, resource, interface} ->
          resource = resource

          action_name = interface.action || interface.name

          action = Ash.Resource.Info.action(resource, action_name)

          resource_attributes = Ash.Resource.Info.attributes(resource)

          try do
            Ash.Resource.Verifiers.ValidateArgumentsToCodeInterface.verify_interface!(
              %{interface | args: form.args},
              action,
              resource_attributes,
              resource
            )
          rescue
            e in Spark.Error.DslError ->
              reraise %{e | path: [:forms, form.name]}, __STACKTRACE__
          end

        :error ->
          raise Spark.Error.DslError,
            module: module,
            path: [:forms, form.name],
            message: """
            Form `#{inspect(form.name)}` does not match an existing code interface definition.

            `form/1` is used to customize existing code interfaces, i.e `define #{inspect(form.name)}, ...`.

            Perhaps you have a typo in `#{inspect(form.name)}`, or have yet to define the interface?
            """
      end
    end)

    :ok
  end

  defp get_interface(dsl_state, form) do
    case Ash.Domain.Info.resource_references(dsl_state) do
      [] ->
        resource = Spark.Dsl.Transformer.get_persisted(dsl_state, :module)

        dsl_state
        |> Ash.Resource.Info.interfaces()
        |> Enum.filter(&match?(%Ash.Resource.Interface{}, &1))
        |> Enum.find_value(:error, fn interface ->
          if interface.name == form.name do
            {:ok, resource, interface}
          end
        end)

      references ->
        references
        |> Enum.find_value(:error, fn reference ->
          reference.definitions
          |> Enum.filter(&match?(%Ash.Resource.Interface{}, &1))
          |> Enum.find_value(fn interface ->
            if interface.name == form.name do
              {:ok, reference.resource, interface}
            end
          end)
        end)
    end
  end
end
