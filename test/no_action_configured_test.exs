alias AshPhoenix.Test.NoActionConfigured, as: ThisTest

defmodule ThisTest.Question do
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    domain: AshPhoenix.Test.DummyDomain

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept :*

      argument :choices, {:array, :map} do
        allow_nil? false
        constraints min_length: 4, max_length: 4
      end

      change manage_relationship(:choices, type: :create)
    end

    update :update do
      primary? true
      require_atomic? false
      accept :*

      argument :choices, {:array, :map} do
        allow_nil? false
        constraints min_length: 4, max_length: 4
        default []
      end

      change manage_relationship(:choices, on_match: {:update, :update})
    end
  end

  attributes do
    attribute :id, :integer, allow_nil?: false, public?: true, primary_key?: true
    attribute :content, :string, allow_nil?: false, public?: true
  end

  relationships do
    has_many :choices, ThisTest.Choice
  end
end

defmodule ThisTest.Choice do
  use Ash.Resource,
    data_layer: Ash.DataLayer.Ets,
    domain: AshPhoenix.Test.DummyDomain

  actions do
    defaults [:read, create: :*, update: :*]
  end

  attributes do
    attribute :id, :integer, allow_nil?: false, public?: true, primary_key?: true
    attribute :content, :string, allow_nil?: false, public?: true
  end

  relationships do
    belongs_to :question, ThisTest.Question do
      attribute_type :integer
      allow_nil? false
    end
  end
end

defmodule ThisTest do
  use ExUnit.Case
  use Ash.Generator

  test "should work without create action configuration" do
    question = generate(question())

    params = %{
      "choices" =>
        Enum.with_index(question.choices)
        |> Map.new(fn {choice, index} ->
          # no error!
          {to_string(index), %{"content" => "updated #{index}"}}

          # no error!
          {to_string(index), %{"content" => "updated #{index}", id: to_string(choice.id)}}

          # error!
          {to_string(index), %{"content" => "updated #{index}", "id" => to_string(choice.id)}}
        end)
    }

    # error!
    AshPhoenix.Form.for_update(question, :update)
    |> Phoenix.Component.to_form()
    |> AshPhoenix.Form.validate(params)
    |> AshPhoenix.Form.params()
    |> IO.inspect()
  end

  def question() do
    changeset_generator(
      ThisTest.Question,
      :create,
      defaults: [
        id: id(),
        choices:
          StreamData.fixed_map(%{id: id(), content: StreamData.string(:utf8, min_length: 1)})
          |> StreamData.list_of(length: 4)
      ]
    )
  end

  defp id() do
    sequence(:id, &Function.identity/1)
  end
end
