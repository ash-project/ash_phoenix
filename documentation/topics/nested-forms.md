<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->

# Nested Forms

Make sure you're familiar with the basics of `AshPhoenix.Form` before reading this guide.

When we talk about "nested" or "related" forms, we mean sets of form inputs
that are for resource actions for related or embedded resources.

For example, you might have a form for creating a "business" that can also
include multiple "locations". In some cases, you may have buttons to add or 
remove from a list of nested forms, you may be able to drag and drop to reorder
forms, etc. In other cases, the form may just be for one related thing, think
a form for updating a "user" that also contains inputs for its associated "profile".

## Defining the structure

### Inferring from the action

`AshPhoenix.Form` automatically infers what "nested forms" are available, based on introspecting actions
which use `change manage_relationship`. For example, in the following action:

```elixir
# on a `MyApp.Operations.Business` resource
create :create do
  accept [:name]

  argument :locations, {:array, :map}

  change manage_relationship(:locations, type: :create)
end
```

With this action, you could submit an input like so:

```elixir
%{name: "Wally World", locations: [%{name: "HQ", address: "1 hq street"}]}
```

`AshPhoenix.Form` will look at the action, allowing you to use `Phoenix`'s
`<.inputs_for` component for `locations`. Here is what it might look like in
practice:

```heex
<.simple_form for={@form} phx-change="validate" phx-submit="submit">
  <.input field={@form[:email]} />

  <.inputs_for :let={location} field={@form[:locations]}>
    <.input field={location[:name]} />
  </.inputs_for>
</.form>
```

To turn this automatic behavior off, you can specify `forms: [auto?: false]` 
when creating the form.

### Manually defining nested forms

You can manually specify nested form configurations using the `forms` option.

For example:

```elixir
AshPhoenix.Form.for_create(
  MyApp.Operations.Business, 
  :create, 
  forms: [
    locations: [
      type: :list,
      resource: MyApp.Operations.Location,
      create_action: :create
    ]
  ]
)
```

You should prefer to use the automatic form definition wherever possible,
but this exists as an escape hatch to customize configuration.

## Updating existing data

You should be sure to load any relationships that are necessary for your
`manage_relationship`s when you want to update the nested items. 
For example, if the form above was for an update action,
you may want to allow updating the existing locations all in a single form.
`AshPhoenix.Form` will show a form for each existing location, but only if
the locations are loaded on the business already. For example:

```elixir
business = Ash.load!(business, :locations)

form = AshPhoenix.Form.for_update(business, :update)
```

> ### Not using tailwind? {: .warning}
>
> If you're not using tailwind, you'll need to replace `class="hidden"`
> in the examples below with something else. In standard HTML, you'd do
> `<input .... hidden />`. As long as the checkbox is hidden, you're good!

## Adding nested forms

There are two ways to add nested forms.

### The `_add_*` checkbox

```heex
<.simple_form for={@form} phx-change="validate" phx-submit="submit">
  <.input field={@form[:email]} />

  <.inputs_for :let={location} field={@form[:locations]}>
    <.input field={location[:name]} />
  </.inputs_for>

  <label>
    <input
      type="checkbox"
      name={"#{@form.name}[_add_locations]"}
      value="end"
      class="hidden"
    />
    <.icon name="hero-plus" />
  </label>
</.form>
```

This checkbox, when checked, will add a parameter like `form[_add_locations]=end`. 
When `AshPhoenix.Form` is handling nested forms, it will see that and append an empty
form at the end. Valid values are `"start"`, `"end"` and an index, i.e `"3"`, in which
case the new form will be inserted at that index.

> ### But the checkbox is hidden, what gives? {: .info}
>
> If you're anything like me, the label + checkbox combo above may confuse you 
> at first sight. When you have a checkbox inside of a label, clicking on the label
> [counts as clicking the checkbox itself](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input/checkbox#providing_a_bigger_hit_area_for_your_checkboxes)!

### `AshPhoenix.Form.add_form`

In some cases, you may want to add a form either in a way that can't be triggered by a checkbox
or that requires some additional data (like non-empty starting params). In those cases,
you can use a button and a `handle_event` For example:

```heex
<.simple_form for={@form} phx-change="validate" phx-submit="submit">
  <.input field={@form[:email]} />

  <.inputs_for :let={location} field={@form[:locations]}>
    <.input field={location[:name]} />
  </.inputs_for>

  <.button type="button" phx-click="add-form" phx-value-path={@form.name <> "[locations]"}>
    <.icon name="hero-plus" />
  </.button>
</.form>
```

> ### whats with `@form.name <> "[locations]"` {: .info}
>
> By always using a path "relative" to the root form, we can handle cases where we are
> adding a form to a multiply-nested form. So the path could be somethign like
> locations[0][addresses][1]. The event handler has to know exactly where we are adding
> a form. In the example above, we *could* just say `add_form(form, :locations)`. It would
> be simpler, but we want to highlight how to work with potentially deeply nested data.

```elixir
def handle_event("add-form", %{"path" => path}, socket) do
  form = AshPhoenix.Form.add_form(socket.assigns.form, path, params: %{
    address: "Put your address here!"
  })

  {:noreply, assign(socket, :form, form)}
end
```

## Removing nested forms

Just like adding nested forms, there are two ways to *remove* nested forms.

### Using the `_drop_*` checkbox

The `_drop_*` checkbox uses checkboxes which add form indices to a list that should
be *removed* from the list. For example, given the following:

```heex
<.simple_form for={@form} phx-change="validate" phx-submit="submit">
  <.input field={@form[:email]} />

  <.inputs_for :let={location} field={@form[:locations]}>
    <.input field={location[:name]} />

    <label>
      <input
        type="checkbox"
        name={"#{@form.name}[_drop_locations][]"}
        value={location.index}
        class="hidden"
      />

      <.icon name="hero-x-mark" />
    </label>
  </.inputs_for>
</.form>
```

When the checkbox is checked, the server sees:

```elixir
%{"form" => %{"_drop_locations" => ["0"]}}
```

We use this information to automatically remove the item at that index on validate.

### Using `AshPhoenix.Form.remove_form`

Just like adding forms, there is a manual way to remove forms. In this case
we pass the full path to the form being removed.

```heex
<.simple_form for={@form} phx-change="validate" phx-submit="submit">
  <.input field={@form[:email]} />

  <.inputs_for :let={location} field={@form[:locations]}>
    <.input field={location[:name]} />

    <.button type="button" phx-click="remove-form" phx-value-path={location.name}>
      <.icon name="hero-x-mark" />
    </.button>
  </.inputs_for>
</.form>
```

```elixir
def handle_event("remove-form", %{"path" => path}, socket) do
  form = AshPhoenix.Form.remove_form(socket.assigns.form, path)

  {:noreply, assign(socket, :form, form)}
end
```

## Sorting nested forms

Just like adding and removing forms, there are two ways to *sort* nested forms too!

### Using `_sort_*` checkboxes

This method is useful when combined with something like [`sortable.js`](https://sortablejs.github.io/Sortable/) 
to allow for dragging and dropping on the front end.

> ### the `order_is_key` option {: .info}
>
> If you are working with a sorted relationship, you will likely want to couple it
> with the `order_is_key` option of `managed_relationships`. This writes the order
> of items in the list of inputs into each input, as if it was provided as an input
>
> `change manage_relationship(:locations, type: :direct_control, order_is_key: :position)`
> In the above example, if you provided a list of inputs like
> `[%{address: "foo"}, %{address: "bar"}]`, it would first be converted into
> `[%{address: "foo, order: 0}, %{address: "bar", order: 1}]` before being
> processed.

Lets say you had the following `Sortable` hook in your `app.js`

```js
import Sortable from "sortablejs"

export const Sortable = {
  mounted() {
    new Sortable(this.el, {
      animation: 150,
      draggable: '[data-sortable="true"]',
      ghostClass: "bg-yellow-100",
      dragClass: "shadow-2xl",
      onEnd: (evt) => {
        this.el.closest("form").querySelector("input").dispatchEvent(new Event("input", {bubbles: true}))
      }
    })
  }
}
...

let Hooks = {}

Hooks.Sortable = Sortable
```

You could use the `_sort_*` checkbox in each nested form like so:

```heex
<.simple_form for={@form} phx-change="validate" phx-submit="submit">
  <.input field={@form[:email]} />

  <div id="location-list" phx-hook="Sortable">
    <.inputs_for :let={location} field={@form[:locations]}>
      <div data-sortable="true">
        <input
          type="hidden"
          name={"#{@form.name}[_sort_locations][]"}
          value={location_form.index}
        />

        <.input field={location[:name]} />
      </div>
    </.inputs_for>
</.form>
```

In this case you'd drag the entire div. `sortable.js` supports all kinds of useful features,
like drag handles. See [their docs](https://sortablejs.github.io/Sortable/) for more. 

Now, lets say you were to drag the second form above the first form, the server would see the
params as:

```elixir
%{"form" => %{"_sort_locations" => ["1", "0"]}}
```

`AshPhoenix.Form` would then sort the nested forms accordingly.

### Using `AshPhoenix.Form.sort_forms/3`

The manual way is using  `AshPhoenix.Form.sort_forms/3`. This can be used
to move a specific element up or down, or to sort all forms. `sortable.js`
can be used in such a way that it provides the full sorting back to your
server. 

#### Providing a full sort order

This could be used to send a `handle_event` that gives you a list
of indices in a new order. An example of that setup can be seen 
[here](https://fullstackphoenix.com/tutorials/sortable-js-phoenix-liveview). Keep in mind that you'll want to adjust the method to extract a field from
each element of the current index, using something like `data-current-index={location_form.index}` to
store the index.

`indices` might look something like this: `["0", "1", "3", "2"]`


```elixir
def handle_event("update-sorting", %{"path" => path, "indices" => indices}, socket) do
  form = AshPhoenix.Form.sort_forms(socket, path, indices)
  {:noreply, assign(socket, form: form)}
end
```

#### Moving a specific form up

If you wanted up/down buttons, you could use event handlers like the following.

```elixir
def handle_event("move-up", %{"path" => form_to_move}, socket) do
  # decrement typically means "move up" visually
  # because forms are rendered down the page ascending
  form = AshPhoenix.Form.sort_forms(socket, form_to_move, :decrement)
  {:noreply, assign(socket, form: form)}
end

def handle_event("move-down", %{"path" => form_to_move}, socket) do
  # increment typically means "move down" visually
  # because forms are rendered down the page ascending
  form = AshPhoenix.Form.sort_forms(socket, form_to_move, :increment)
  {:noreply, assign(socket, form: form)}
end
```

## Putting it all together

Lets look at what it looks like with all of the checkbox-based features in one:

```elixir
defmodule MyApp.MyForm do
  use MyAppWeb, :live_view

  def render(assigns) do
    ~H"""
    <.simple_form for={@form} phx-change="validate" phx-submit="submit">
      <.input field={@form[:email]} />

      <!-- Use sortable.js to allow sorting nested input -->
      <div id="location-list" phx-hook="Sortable">
        <.inputs_for :let={location} field={@form[:locations]}>
          <!-- inputs each nested location -->
          <div data-sortable="true">
            <!-- AshPhoenix.Form automatically applies this sort -->
            <input
              type="hidden"
              name={"#{@form.name}[_sort_locations][]"}
              value={location_form.index}
            />

            <.input field={location[:name]} />

            <!-- AshPhoenix.Form automatically removes items when checked -->
            <label>
              <input
                type="checkbox"
                name={"#{@form.name}[_drop_locations][]"}
                value={location_form.index}
                class="hidden"
              />

              <.icon name="hero-x-mark" />
            </label>
          </div>
        </.inputs_for>

        <!-- AshPhoenix.Form automatically appends a new item when checked -->
        <label>
          <input
            type="checkbox"
            name={"#{@form.name}[_add_locations]"}
            value="end"
            class="hidden"
          />
          <.icon name="hero-plus" />
        </label>
      </div>
    </.form>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: MyApp.Operations.form_to_create_business())}
  end

  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("submit", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, business} ->
        socket =
          socket
          |> put_flash(:success, "Business created successfully")
          |> push_navigate(to: ~p"/businesses/#{business.id}")

        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end
end
```
