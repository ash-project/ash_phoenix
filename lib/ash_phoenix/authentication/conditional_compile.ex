defmodule AshPhoenix.Authentication.ConditionalCompile do
  @moduledoc """
  Contains a single `use` macro which enables conditional complication based on
  the presence of the `ash_authentication` application.
  """
  alias __MODULE__
  require Logger

  @doc false
  @spec __using__(any) :: Macro.t()
  defmacro __using__(_opts) do
    quote do
      require ConditionalCompile

      @on_definition ConditionalCompile
      @before_compile ConditionalCompile
      Module.register_attribute(__MODULE__, :optional_funs, accumulate: true)
    end
  end

  @doc false
  @spec __on_definition__(Macro.Env.t(), atom, atom, [Macro.t()], any, any) :: any
  def __on_definition__(env, kind, name, args, _, _) when kind in [:def, :defmacro] do
    if Module.get_attribute(env.module, :optional, false) do
      Module.put_attribute(env.module, :optional_funs, {kind, name, args})
      Module.delete_attribute(env.module, :optional)
    end
  end

  def __on_definition__(env, kind, name, args, _, _) do
    if Module.get_attribute(env.module, :optional, false) do
      Logger.warning(fn ->
        arity = length(args)

        "#{env.file}:#{env.line} Attribute `@optional` has no meaning for #{kind} in #{name}/#{arity}."
      end)

      Module.delete_attribute(env.module, :optional)
    end
  end

  @doc false
  @spec __before_compile__(Macro.Env.t()) :: Macro.t()
  def __before_compile__(env) do
    optional_funs = Module.get_attribute(env.module, :optional_funs, [])

    Module.delete_attribute(env.module, :optional_funs)

    unless ConditionalCompile.authentication_present?() do
      for {kind, name, args} <- optional_funs do
        arity = length(args)

        ignored_args =
          args
          |> Enum.map(fn {name, metadata, value} ->
            {:"_#{name}", metadata, value}
          end)

        Module.delete_definition(env.module, {name, arity})

        replacement =
          case kind do
            :def ->
              quote do
                def unquote(name)(unquote_splicing(ignored_args)) do
                  raise "AshAuthentication is not enabled."
                end
              end

            :defmacro ->
              quote do
                defmacro unquote(name)(unquote_splicing(ignored_args)) do
                  quote do
                    raise "AshAuthentication is not enabled."
                  end
                end
              end
          end

        Module.eval_quoted(env.module, replacement)
      end
    end
  end

  @doc """
  Checks to see if the `AshAuthentication` module is available.
  """
  @spec authentication_present? :: boolean
  def authentication_present? do
    Enum.any?(:code.all_available(), &(elem(&1, 0) == 'Elixir.AshAuthentication'))
  end
end
