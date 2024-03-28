defmodule AshPhoenix.Form.WrappedValue do
  @moduledoc "A sentinal value used when editing a union that has non-map values"
  use Ash.Resource,
    data_layer: :embedded

  attributes do
    attribute :value, :term, public?: true
  end

  actions do
    default_accept :*
    defaults []

    create :create do
      primary? true
    end

    update :update do
      primary? true
    end
  end

  changes do
    change fn changeset, _ ->
      if Ash.Changeset.changing_attribute?(changeset, :value) do
        value = Ash.Changeset.get_attribute(changeset, :value)

        with constraints <-
               Ash.Type.include_source(
                 changeset.context.type,
                 changeset,
                 changeset.context.constraints
               ),
             {:ok, casted} <-
               Ash.Type.cast_input(
                 changeset.context.type,
                 value,
                 changeset.context.constraints
               ),
             {:constrained, {:ok, casted}} when not is_nil(casted) <-
               {:constrained,
                Ash.Type.apply_constraints(
                  changeset.context.type,
                  casted,
                  changeset.context.constraints
                )} do
          Ash.Changeset.force_change_attribute(changeset, :value, casted)
        else
          {:constrained, {:ok, nil}} ->
            Ash.Changeset.force_change_attribute(changeset, :value, nil)

          {:constrained, {:error, error}, argument} ->
            add_invalid_errors(value, changeset, :value, error)

          {:error, error} ->
            add_invalid_errors(value, changeset, :value, error)
        end
      else
        changeset
      end
    end
  end

  defp add_invalid_errors(value, changeset, attribute, message) do
    messages =
      if Keyword.keyword?(message) do
        [message]
      else
        List.wrap(message)
      end

    Enum.reduce(messages, changeset, fn message, changeset ->
      if is_exception(message) do
        error =
          message
          |> Ash.Error.to_ash_error()

        errors =
          case error do
            %class{errors: errors}
            when class in [
                   Ash.Error.Invalid,
                   Ash.Error.Unknown,
                   Ash.Error.Forbidden,
                   Ash.Error.Framework
                 ] ->
              errors

            error ->
              [error]
          end

        Enum.reduce(errors, changeset, fn error, changeset ->
          Ash.Changeset.add_error(changeset, Ash.Error.set_path(error, attribute))
        end)
      else
        opts = Ash.Type.Helpers.error_to_exception_opts(message, %{name: attribute})

        Enum.reduce(opts, changeset, fn opts, changeset ->
          error =
            Ash.Error.Changes.InvalidAttribute.exception(
              value: value,
              field: Keyword.get(opts, :field),
              message: Keyword.get(opts, :message),
              vars: opts
            )

          error =
            if opts[:path] do
              Ash.Error.set_path(error, opts[:path])
            else
              error
            end

          Ash.Changeset.add_error(changeset, error)
        end)
      end
    end)
  end
end
