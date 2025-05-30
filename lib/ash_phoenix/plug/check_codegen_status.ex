defmodule AshPhoenix.Plug.CheckCodegenStatus do
  @moduledoc """
  A plug that checks if there are pending codegen tasks for your application.
  """

  @behaviour Plug

  alias Plug.Conn

  def init(opts) do
    opts
  end

  def call(%Conn{} = conn, _opts) do
    extensions =
      :persistent_term.get(:ash_codegen_extensions, nil) ||
        set_extensions()

    Enum.flat_map(extensions, fn extension ->
      try do
        if function_exported?(extension, :codegen, 1) do
          extension.codegen(["--dev", "--check"])
        end

        []
      rescue
        e in Ash.Error.Framework.PendingCodegen ->
          Enum.to_list(e.diff)

        _ ->
          []
      end
    end)
    |> case do
      [] ->
        conn

      diff ->
        {:current_stacktrace, stack} = Process.info(self(), :current_stacktrace)

        Plug.Conn.WrapperError.reraise(
          conn,
          :error,
          Ash.Error.Framework.PendingCodegen.exception(diff: diff, explain: true),
          Enum.drop(stack, 1)
        )
    end
  end

  defp set_extensions do
    extensions = Ash.Mix.Tasks.Helpers.extensions!([])
    :persistent_term.put(:ash_codegen_extensions, extensions)
    extensions
  end

  # defp check_pending_migrations!(repo, opts) do
  #   dirs = migration_directories(repo, opts)

  #   migrations_fun =
  #     Keyword.get_lazy(opts, :mock_migrations_fn, fn ->
  #       if Code.ensure_loaded?(Ecto.Migrator),
  #         do: &Ecto.Migrator.migrations/3,
  #         else: fn _repo, _paths, _opts -> raise "to be rescued" end
  #     end)

  #   true = is_function(migrations_fun, 3)
  #   migration_opts = Keyword.take(opts, @migration_opts)

  #   try do
  #     repo
  #     |> migrations_fun.(dirs, migration_opts)
  #     |> Enum.any?(fn {status, _version, _migration} -> status == :down end)
  #   rescue
  #     _ -> false
  #   else
  #     true ->

  #     false ->
  #       true
  #   end
  # end

  # defp migration_directories(repo, opts) do
  #   case Keyword.fetch(opts, :migration_paths) do
  #     {:ok, migration_directories_fn} ->
  #       List.wrap(migration_directories_fn.(repo))

  #     :error ->
  #       try do
  #         [Ecto.Migrator.migrations_path(repo)]
  #       rescue
  #         _ -> []
  #       end
  #   end
  # end
end
