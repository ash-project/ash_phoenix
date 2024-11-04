defmodule Mix.Tasks.AshPhoenix.Gen.LiveTest do
  use ExUnit.Case
  import Igniter.Test

  setup do
    current_shell = Mix.shell()

    :ok = Mix.shell(Mix.Shell.Process)

    on_exit(fn ->
      Mix.shell(current_shell)
    end)
  end

  test "generate phoenix live views from resource" do
    send(self(), {:mix_shell_input, :yes?, "n"})
    send(self(), {:mix_shell_input, :prompt, ""})

    opts = [
      files: %{
        "lib/test/support/ticket/status.ex" => """
        defmodule Test.Support.Ticket.Status do
          use Ash.Type.Enum, values: [:open, :closed]
        end
        """,
        "lib/test/support/ticket.ex" => """
        defmodule Test.Support.Ticket do
          use Ash.Resource,
          otp_app: :test,
          domain: Test.Support,
          data_layer: Ash.DataLayer.Ets

          alias Test.Support.Ticket.Status

          ets do
            private? true
          end

          actions do
            defaults [:read, :destroy]

            create :create do
              accept [:subject, :status]
            end

            create :open do
              accept [:subject]
            end

            update :update do
              primary? true
              accept [:subject]
            end

            update :close do
              accept []

              validate attribute_does_not_equal(:status, :closed) do
                message "Ticket is already closed"
              end

              change set_attribute(:status, :closed)
            end

            update :assign do
              accept [:representative_id]
            end
          end


          attributes do
            uuid_primary_key :id

            attribute :subject, :string do
              allow_nil? false
              public? true
            end

            attribute :status, Status do
              default :open
              allow_nil? false
            end
          end
        end
        """,
        "lib/test/support.ex" => """
        defmodule Test.Support do
          use Ash.Domain

          resources do
            resource Test.Support.Ticket
          end
        end
        """
      }
    ]

    assert test_project(opts)
           |> apply_igniter!()
           |> compile()
           |> Igniter.compose_task("ash_phoenix.gen.live", [
             "--domain",
             "Elixir.Test.Support",
             "--resource",
             "Elixir.Test.Support.Ticket",
             "--resourceplural",
             "Tickets"
           ])
  end

  def compile(igniter) do
    igniter.rewrite
    |> Stream.map(fn source ->
      Kernel.ParallelCompiler.async(fn ->
        Code.compile_string(Rewrite.Source.get(source, :content))
      end)
    end)
    |> Enum.to_list()

    igniter
  end
end
