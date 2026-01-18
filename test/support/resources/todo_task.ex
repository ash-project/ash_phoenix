# SPDX-FileCopyrightText: 2020 ash_phoenix contributors <https://github.com/ash-project/ash_phoenix/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshPhoenix.Test.TodoTask do
  @moduledoc false
  use Ash.Resource,
    domain: AshPhoenix.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  require Ash.Query

  resource do
    ets do
      private? true
    end

    actions do
      defaults [:read, :destroy]

      create :create do
        accept [:id]
        argument :contexts, {:array, :map}, allow_nil?: true, default: []

        change manage_relationship(:contexts, :context_relationships, type: :direct_control)
      end

      update :update do
        accept [:name]
        argument :contexts, {:array, :integer}, allow_nil?: true, default: []
        require_atomic? false

        change manage_relationship(:contexts, :context_relationships,
                 value_is_key: :context_id,
                 type: :direct_control
               )
      end

      update :update_with_actions do
        accept [:name]
        argument :actions, {:array, :map}, default: []
        require_atomic? false

        change manage_relationship(:actions, :actions,
                 type: :direct_control,
                 debug?: true
               )
      end
    end

    attributes do
      integer_primary_key :id, writable?: true
      attribute :name, :string
    end

    relationships do
      has_many :actions, AshPhoenix.Test.TaskAction do
        destination_attribute :task_id
      end

      has_many :context_relationships, AshPhoenix.Test.TodoTaskContext do
        destination_attribute :task_id
      end

      many_to_many :contexts, AshPhoenix.Test.Context do
        join_relationship :context_relationships
        source_attribute_on_join_resource :task_id
        destination_attribute_on_join_resource :context_id
      end
    end
  end
end

defmodule AshPhoenix.Test.Context do
  @moduledoc false
  use Ash.Resource,
    domain: AshPhoenix.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  ets do
    private? true
  end

  resource do
    attributes do
      integer_primary_key :id
    end
  end

  actions do
    defaults [:read, :create, :update, :destroy]
  end
end

defmodule AshPhoenix.Test.TodoTaskContext do
  @moduledoc false
  use Ash.Resource,
    domain: AshPhoenix.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  resource do
    ets do
      private? true
    end

    actions do
      defaults [:create, :read, :update, :destroy]
      default_accept [:task_id, :context_id]
    end

    relationships do
      belongs_to :task, AshPhoenix.Test.TodoTask do
        attribute_type :integer
        allow_nil? false
        primary_key? true
      end

      belongs_to :context, AshPhoenix.Test.Context do
        attribute_type :integer
        allow_nil? false
        primary_key? true
      end
    end
  end
end

defmodule AshPhoenix.Test.TaskAction do
  @moduledoc false
  use Ash.Resource,
    domain: AshPhoenix.Test.Domain,
    data_layer: Ash.DataLayer.Ets

  resource do
    ets do
      private? true
    end

    actions do
      defaults [:create, :read, :update, :destroy]

      default_accept :*
    end

    attributes do
      integer_primary_key :id, writable?: true
      attribute :description, :string, public?: true

      attribute :status, :atom,
        constraints: [one_of: [:done, :pending, :postponed]],
        default: :pending,
        public?: true
    end

    relationships do
      belongs_to :task, AshPhoenix.Test.TodoTask do
        attribute_type :integer
        allow_nil? false
      end
    end
  end
end
