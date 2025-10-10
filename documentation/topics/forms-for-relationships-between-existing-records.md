<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->

# Forms For Relationships Between Existing Records

Make sure you're familiar with the basics of `AshPhoenix.Form` and relationships before reading this guide.

When we talk about "relationships between existing records", we mean inputs on a form that manage the relationships between records that already exist.

For example, you might have a form for creating a "service" that can be performed at some "locations", but not others.
When creating or updating a service, the user is only able to select from the existing locations.

## Defining the resources and relationships

First, we have a simple `Location`

```elixir
defmodule MyApp.Operations.Location do
  use Ash.Resource,
    otp_app: :my_app,
    domain: MyApp.Operations,
    data_layer: AshPostgres.DataLayer

  ...

  attributes do
    integer_primary_key :id

    attribute :name, :string do
      allow_nil? false
    end
  end
end
```

Then we have a `Service`, which has a `many_to_many` association to `Location`, through `ServiceLocation`.
We add a `list` aggregate for `:location_ids` for populating the form values.

```elixir
defmodule MyApp.Operations.Service do
  use Ash.Resource,
    otp_app: :my_app,
    domain: MyApp.Operations,
    data_layer: AshPostgres.DataLayer

  ...

  relationships do
    has_many :location_relationships, MyApp.Operations.ServiceLocation do
      destination_attribute :service_id
    end

    many_to_many :locations, MyApp.Operations.Location do
      join_relationship :location_relationships
      source_attribute_on_join_resource :service_id
      destination_attribute_on_join_resource :location_id
    end
  end

  aggregates do
    list :location_ids, :locations, :id
  end
end
```

`ServiceLocation` has default `actions` as well as the `relationships` declared to operate as the joining resource between a `Service` and one or more `Location`s.

```elixir
defmodule MyApp.Operations.ServiceLocation do
  use Ash.Resource,
    otp_app: :my_app,
    domain: MyApp.Operations,
    data_layer: AshPostgres.DataLayer

  ...

  actions do
    defaults [:create, :read, :update, :destroy]
    default_accept [:service_id, :location_id]
  end

  relationships do
    belongs_to :service, MyApp.Operations.Service do
      attribute_type :integer
      allow_nil? false
      primary_key? true
    end

    belongs_to :location, MyApp.Operations.Location do
      attribute_type :integer
      allow_nil? false
      primary_key? true
    end
  end
end
```

## Declaring the `create` and `update` actions

First, we need to update our `Service` and declare custom `create` and `update` actions, which take a list of `Location` ids as an argument.
We use `type: :append_and_remove` to cause a `ServiceLocation` to be added or removed for each `Location` as we add and remove them using our form.
(See `Ash.Changeset.manage_relationship/4` for more.)

```elixir
# in lib/my_app/operations/service.ex
create :create do
  accept [:name]
  primary? true
  argument :location_ids, {:array, :integer}, allow_nil?: true

  change manage_relationship(:location_ids, :locations, type: :append_and_remove)
end

update :update do
  accept [:name]
  primary? true
  argument :location_ids, {:array, :integer}, allow_nil?: true
  require_atomic? false

  change manage_relationship(:location_ids, :locations, type: :append_and_remove)
end
```

Note: in this example, we are using `integer_primary_key`, so the argument's type is `{:array, :integer}`.
If we were using `uuid_primary_key`, the type would be `{:array, :uuid}`.

Now we can create and update our `Services`.

```elixir
iex> service = Ash.create!(Service, %{name: "Tuneup", location_ids: [location_1_id, location_2_id]}, load: [:locations])
 %MyApp.Operations.Service{
  id: 9,
  name: "Tuneup",
  location_relationships: [
    %MyApp.Operations.ServiceLocation{ service_id: 9, location_id: 1, ... },
    %MyApp.Operations.ServiceLocation{ service_id: 9, location_id: 2, ... }
  ],
  locations: [
    %MyApp.Operations.Location{ id: 1, name: "HQ", ... },
    %MyApp.Operations.Location{ id: 2, name: "Downtown", ... }
  ],
  ...
}
iex> Ash.update!(service, %{location_ids: [location_2_id]}, load: [:locations])
%MyApp.Operations.Service{
  id: 9,
  name: "Tuneup",
  location_relationships: [
    %MyApp.Operations.ServiceLocation{ service_id: 9, location_id: 2, ... }
  ],
  locations: [
    %MyApp.Operations.Location{ id: 2, name: "Downtown", ... }
  ],
  ...
}
```

Now, let's expose this to a user.

## Adding the forms

In our view, we create our form as normal.
For update forms, we'll make sure to load our `locations`.

We use the `:prepare_params` option with our `for_update` form to set `"location_ids"` to an empty list if no value is provided.
This allows the user to de-select all `Location`s to update a `Service` so that it's not available at any `Location`.

```elixir
# lib/my_app_web/service_live/form_component.ex
defp assign_form(%{assigns: %{service: service}} = socket) do
  form =
    if service do
      service
      |> Ash.load!([:locations, :location_ids])
      |> AshPhoenix.Form.for_update(:update, as: "service", prepare_params: &prepare_params/2)
    else
      AshPhoenix.Form.for_create(MyApp.Operations.Service, :create, as: "service")
    end

  assign(socket, form: to_form(form))
end

defp prepare_params(params, :validate) do
  Map.put_new(params, "location_ids", [])
end
```

When rendering the form, we'll have to manually provide the `options` to our `input`.
Using Phoenix generated core components, `options` is passed to `Phoenix.HTML.Form.options_for_select/2`, which expects a list of two-element tuples.

Assuming the available `Location`s are already assigned to `@locations`:
```elixir
<.input
  field={@form[:location_ids]}
  type="select"
  multiple
  label="Locations"
  options={Enum.map(@locations, &{&1.name, &1.id})}
/>
```

Now, when our form is submitted, we will receive a list of location ids.

```elixir
%{"service" => %{"locations" => ["1", "2"], "name" => "Overhaul"}}
```

That's all we need to do.
We can pass these parameters to `AshPhoenix.Form.submit/2` as normal and `manage_relationship` will create and destroy our `ServiceLocation` records as needed.
