# Get Started with Ash and Phoenix

<!--- ash-hq-hide-start --> <!--- -->

This documentation is best viewed at [ash-hq.org](https://ash-hq.org)

<!--- ash-hq-hide-stop --> <!--- -->

## Who is This For?

This is designed to be a quick start guide for Ash with Phoenix. Familiarity with Phoenix and LiveView are not necessary, but would certainly be helpful.

## Goals

In this guide we will:

1. Create a new Phoenix project
2. Setup Ash, AshPhoenix and AshPostgres as dependencies
3. Create a basic `Blog.Post` resource
4. Create and migrate the database
5. Learn how to interact with your resource
6. Integrate a minimal Phoenix LiveView with Ash

## Things You May Want to Read First

- [Install Elixir](https://elixir-lang.org/install.html)
- [Phoenix - Up and Running Guide](https://hexdocs.pm/phoenix/up_and_running.html)
- [Philosophy Guide](https://hexdocs.pm/ash/philosophy.html)

## Requirements

If you want to follow along yourself, you will need the following things:

1. Elixir (1.12 or later) and Erlang (22 or later) installed
2. PostgreSQL installed
3. A text editor
4. A terminal to run the examples

## Setup

### Create a New Phoenix Project

_This section is based on the [Phoenix installation docs](https://hexdocs.pm/phoenix/installation.html). For more details go there._

First we need to install the Phoenix project generator, then we'll run the generator to create our new project.

**NOTE: DO NOT run `mix ecto.create`, (as it asks you to) we will do this the Ash way later.**

```bash
# install Phoenix project generator
$ mix archive.install hex phx_new

# generate Phoenix project
$ mix phx.new my_ash_phoenix_app

# cd into project
$ cd my_ash_phoenix_app
```

### Add Dependencies

We now need to add Ash, AshPhoenix and AshPostgres to our Phoenix project. We need to add the dependencies to the `deps` function in our `mix.exs`. We'll also need to add dependencies to our `.formatter.exs` to ensure consistent formatting when using `mix format`.

```elixir
# mix.exs

  def deps do
    [
      # use `mix hex.info <library_name>` to get the latest versions of each dependency, for example, `mix hex.info phoenix`
      {:phoenix, "~> x.x"},
      # ...
      {:ash, "~> x.x"},
      {:ash_postgres, "~> x.x"},
      {:ash_phoenix, "~> x.x"}
    ]
  end
```

Add `:ash`, `:ash_phoenix`, and `:ash_postgres` to your `.formatter.exs` file.

```elixir
# .formatter.exs
[
  import_deps: [..., :ash, :ash_phoenix, :ash_postgres],
  ...
]
```

Now in the terminal install these new dependencies.

```bash
$ mix deps.get
```

### Use `AshPostgres.Repo`

We need to swap `Ecto.Repo` for `AshPostgres.Repo`. `AshPostgres.Repo` enriches your repo with additional AshPostgres specific behaviour, but is essentially a thin wrapper around `Ecto.Repo`.
To use `AshPostgres.Repo` change your repo module to look like this:

```elixir
# lib/my_ash_phoenix_app/repo.ex

defmodule MyAshPhoenixApp.Repo do
  use AshPostgres.Repo, otp_app: :my_ash_phoenix_app

  # Installs Postgres extensions that ash commonly uses
  def installed_extensions do
    ["uuid-ossp", "citext"]
  end
end
```

### Edit Config

We need to specify the Ash domains that our application uses and some config for backwards compatibility that will be removed in the next major release.

Add this to your config:

```elixir
# config/config.exs

import Config

config :my_ash_phoenix_app,
  ash_domains: [MyAshPhoenixApp.Blog]
```

### Create the Domain and add Resources

An Ash domain can be thought of as a [Bounded Context](https://martinfowler.com/bliki/BoundedContext.html) in Domain Driven Design terms and can seen as analogous to a Phoenix context. Put simply, its a way of grouping related resources together. In our case our domain will be called `MyAshPhoenixApp.Blog`.

An Ash domain points to Ash resources. An Ash domain can point to one or more resources. In our case we will only have a single resource `MyAshPhoenixApp.Blog.Post`. We'll be taking a deeper look into that in the next section.

For now take a look at the `Blog` domain and the associated resources:

```elixir
# lib/my_ash_phoenix_app/blog/blog.ex

defmodule MyAshPhoenixApp.Blog do
  use Ash.Domain

  resources do
    resource MyAshPhoenixApp.Blog.Post
  end
end
```

## Creating Resources

### Creating the `Post` Resource

A resource is a central concept in Ash. In short, a resource is a domain model object in your system. A resource defines the data it holds and defines the actions that can operate on that data.

It's convention to place all the resource in their own resources folder. So when we create `Post` we will place it in `lib/my_ash_phoenix_app/blog/resources/post.ex`. So the structure after making the resource should look like so:

```
lib/
├─ my_ash_phoenix_app/
│  ├─ blog/
│  │  ├─ blog.ex
│  │  ├─ resources/
│  │  │  ├─ post.ex
```

Below is the resource module. Read the comments carefully, every line is explained:

```elixir
# lib/my_ash_phoenix_app/blog/resources/post.ex

defmodule MyAshPhoenixApp.Blog.Post do
  # Using Ash.Resource turns this module into an Ash resource.
  use Ash.Resource,
    # Tells Ash you want this resource to store its data in Postgres.
    data_layer: AshPostgres.DataLayer

  # The Postgres keyword is specific to the AshPostgres module.
  postgres do
    # Tells Postgres what to call the table
    table "posts"
    # Tells Ash how to interface with the Postgres table
    repo MyAshPhoenixApp.Repo
  end

  # Defines convenience methods for
  # interacting with the resource programmatically.
  code_interface do
    define_for MyAshPhoenixApp.Blog
    define :create, action: :create
    define :read_all, action: :read
    define :update, action: :update
    define :destroy, action: :destroy
    define :get_by_id, args: [:id], action: :by_id
  end

  actions do
    # Exposes default built in actions to manage the resource
    defaults [:create, :read, :update, :destroy]

    # Defines custom read action which fetches post by id.
    read :by_id do
      # This action has one argument :id of type :uuid
      argument :id, :uuid, allow_nil?: false
      # Tells us we expect this action to return a single result
      get? true
      # Filters the `:id` given in the argument
      # against the `id` of each element in the resource
      filter expr(id == ^arg(:id))
    end
  end

  # Attributes are simple pieces of data that exist in your resource
  attributes do
    # Add an autogenerated UUID primary key called `:id`.
    uuid_primary_key :id
    # Add a string type attribute called `:title`
    attribute :title, :string do
      # We don't want the title to ever be `nil`
      allow_nil? false
    end

    # Add a string type attribute called `:content`
    # If allow_nil? is not specified, then content can be nil
    attribute :content, :string
  end
end
```

### Creating and Migrating the Database

We have specified the resource in Ash. But we have yet to create it in our data layer (in our case Postgres).

First we need to create our database:

```bash
$ mix ash_postgres.create

The database for MyAshPhoenixApp.Repo has been created
```

Now we need to populate our database. We do this by generating and performing a migration.

We can use a generator to produce a migration for us. Ash can deduce what needs to go into the migration and do the hard work for us, to do this use the command below:

```bash
$ mix ash_postgres.generate_migrations --name initial_migration

# ... don't worry about other files it creates

Generating Migrations:
* creating priv/repo/migrations/20230208045101_initial_migration.exs
```

Here is the migration file commented in detail:

```elixir
# priv/repo/migrations/20230208045101_initial_migration.exs

defmodule MyAshPhoenixApp.Repo.Migrations.InitialMigration do
  use Ecto.Migration

  # This function runs when migrating forward
  def up do
    # Creates the `:posts` table
    create table(:posts, primary_key: false) do
      # Adds primary key attribute `:id` of type `:uuid`
      # null values are not allowed
      add :id, :uuid, null: false, default: fragment("uuid_generate_v4()"), primary_key: true

      # Adds attribute `:title` of type `:text`, null values are not allowed
      add :title, :text, null: false
      # Adds attribute `:content` of type `:text`, null values are allowed
      add :content, :text
    end
  end

  # This is the function that runs if you want to rollback the migration.
  def down do
    # Deletes the `:posts` table
    drop table(:posts)
  end
end
```

We can run the `up/0` function which will perform the desired operations on the Postgres database. We do this with the migrate command:

```bash
$ mix ash_postgres.migrate
```

> In case you want to drop the database and start over again during development you can use `mix ash_postgres.drop` followed by `mix ash_postgres.create` and `mix ash_postgres.migrate`.

## Interacting with your Resources

**All interaction with your resource attributes always occur through an action**. In our resource we are using the default actions for `:create, :read, :update, :destroy` along with a custom action `:by_id`.

`:create` and `:update` and `:destroy` actions require a changeset. Ash changesets are conceptually similar to [Ecto changesets](https://hexdocs.pm/ecto/Ecto.Changeset.html). They're data structures which represent an intended change to an Ash resource and provide validation.

The `:read` action takes a query instead of a changeset.

Below is the most verbose way of calling your resource. All other ways of interaction are some kind of shorthand of these. This means at some point a changeset is being created and passed to the domain, even if it's encapsulated within another function.

```elixir
# create post
new_post =
  MyAshPhoenixApp.Blog.Post
  |> Ash.Changeset.for_create(:create, %{title: "hello world"})
  |>  MyAshPhoenixApp.Blog.create!()

# read all posts
MyAshPhoenixApp.Blog.Post
|> Ash.Query.for_read(:read)
|> MyAshPhoenixApp.Blog.read!()

# get single post by id
MyAshPhoenixApp.Blog.Post
|> Ash.Query.for_read(:by_id, %{id: new_post.id})
|> MyAshPhoenixApp.Blog.read_one!()

# update post
updated_post =
  new_post
  |> Ash.Changeset.for_update(:update, %{content: "hello to you too!"})
  |> MyAshPhoenixApp.Blog.update!()

# delete post
new_post
|> Ash.Changeset.for_destroy(:destroy)
|> MyAshPhoenixApp.Blog.destroy!()
```

As stated above, this is verbose so Ash has a built in shortcut - The `code_interface`. You may notice this has already been done in your `Post` resource. Here it is again with more explanation:

```elixir
 code_interface do
    # defines the domain this resource should be called from
    define_for MyAshPhoenixApp.Blog
    # defining function Post.create/2 it calls the :create action
    define :create, action: :create
    # defining function Post.read_all/2 it calls the :read action
    define :read_all, action: :read
    # defining function Post.update/2 it calls the :update action
    define :update, action: :update
    # defining function Post.destroy/2 it calls the :destroy action
    define :destroy, action: :destroy
    # defining function Post.get_by_id/2
    # it calls the :by_id action with the argument :id
    define :get_by_id, args: [:id], action: :by_id
  end
```

> Note: The function name doesn't have to match the action name in any way. You could also write:
>
> ```elixir
> define :make, action: :create
> ```
>
> That's perfectly valid and could be called via `Blog.Post.make/2`.

Now we can call our resource like so:

```elixir
# create post
new_post = MyAshPhoenixApp.Blog.Post.create!(%{title: "hello world"})

# read post
MyAshPhoenixApp.Blog.Post.read_all!()

# get post by id
MyAshPhoenixApp.Blog.Post.get_by_id!(new_post.id)

# update post
updated_post = MyAshPhoenixApp.Blog.Post.update!(new_post, %{content: "hello to you too!"})

# delete post
MyAshPhoenixApp.Blog.Post.destroy!(updated_post)
```

Now isn't that more convenient?

> Note: All functions that interact with an Ash resource have a safe and unsafe version. For example there are two create functions `create/2` and `create!/2`. `create/2` returns `{:ok, resource}` or `{:error, reason}`. `create!/2` will return just the resource on success and will raise an error on failure.

## Connecting your Resource to a Phoenix LiveView

Now we know how to interact with our resource, let's connect it to a simple Phoenix LiveView. Here is the LiveView below. If you are using phoenix live_view <= 0.18, you will need to use `let={}` instead of `:let={}`.

```elixir
# lib/my_ash_phoenix_app_web/posts_live.ex

defmodule MyAshPhoenixAppWeb.PostsLive do
  use MyAshPhoenixAppWeb, :live_view
  alias MyAshPhoenixApp.Blog.Post

  def render(assigns) do
    ~H"""
    <h2>Posts</h2>
    <div>
    <%= for post <- @posts do %>
      <div>
        <div><%= post.title %></div>
        <div><%= if Map.get(post, :content), do: post.content, else: "" %></div>
        <button phx-click="delete_post" phx-value-post-id={post.id}>delete</button>
      </div>
    <% end %>
    </div>
    <h2>Create Post</h2>
    <.form :let={f} for={@create_form} phx-submit="create_post">
      <.input type="text" field={f[:title]} placeholder="input title" />
      <.button type="submit">create</.button>
    </.form>
    <h2>Update Post</h2>
    <.form :let={f} for={@update_form} phx-submit="update_post">
      <.label>Post Name</.label>
      <.input type="select" field={f[:post_id]} options={@post_selector} />
      <.input type="text" field={f[:content]} placeholder="input content" />
      <.button type="submit">Update</.button>
    </.form>
    """
  end

  def mount(_params, _session, socket) do
    posts = Post.read_all!()

    socket =
      assign(socket,
        posts: posts,
        post_selector: post_selector(posts),
        # the `to_form/1` calls below are for liveview 0.18.12+. For earlier versions, remove those calls
        create_form: AshPhoenix.Form.for_create(Post, :create) |> to_form(),
        update_form: AshPhoenix.Form.for_update(List.first(posts, %Post{}), :update) |> to_form()
      )

    {:ok, socket}
  end

  def handle_event("delete_post", %{"post-id" => post_id}, socket) do
    post_id |> Post.get_by_id!() |> Post.destroy!()
    posts = Post.read_all!()

    {:noreply, assign(socket, posts: posts, post_selector: post_selector(posts))}
  end

  def handle_event("create_post", %{"form" => %{"title" => title}}, socket) do
    Post.create(%{title: title})
    posts = Post.read_all!()

    {:noreply, assign(socket, posts: posts, post_selector: post_selector(posts))}
  end

  def handle_event("update_post", %{"form" => form_params}, socket) do
    %{"post_id" => post_id, "content" => content} = form_params

    post_id |> Post.get_by_id!() |> Post.update!(%{content: content})
    posts = Post.read_all!()

    {:noreply, assign(socket, posts: posts, post_selector: post_selector(posts))}
  end

  defp post_selector(posts) do
    for post <- posts do
      {post.title, post.id}
    end
  end
end
```

Don't forget to add the LiveView to your router.

```elixir
# lib/my_ash_phoenix_app_web/router.ex
  scope "/", MyAshPhoenixAppWeb do
    # ...
    live "/posts", PostsLive
  end
```

All being well you should be able to load up what we have just created on http://localhost:4000/posts.

You can see how using functions created by our `code_interface` makes it easy to integrate Ash with Phoenix.

You may also notice this is the first time we've used the AshPhoenix library. The AshPhoenix library contains utilities to help Ash integrate with Phoenix and LiveView Seamlessly. One of these utilities is `AshPhoenix.Form` which can automatically produce changesets to be used in the forms.

That's it for this guide. We've gone from 0 to a fully working Phoenix App using Ash. To get a closer look, see the accompanying repo [here](https://github.com/team-alembic/my_ash_phoenix_project).

## Where to Next?

We are really just scratching the surface of what can be done in Ash. Look below for what to look at next.

### Continue Learning

There's a few places you can go to learn more about how to use ash:

- Read more about how to query the data in your resources - `Ash.Query`
- [Dig deeper into actions.](https://hexdocs.pm/ash/actions.html)
- [Study resource relationship management](https://hexdocs.pm/ash/managing-relationships.html)

### Ash Authentication & Ash Authentication Phoenix

See the power Ash can bring to your web app or API. [Get authentication working in minutes](https://hexdocs.pm/ash_authentication_phoenix/getting-started-with-ash-authentication-phoenix.html).

### Add an API (or two)

Check out the [AshJsonApi](https://hexdocs.pm/ash_json_api/getting-started-with-json-api.html) and [AshGraphql](https://hexdocs.pm/ash_graphql/getting-started-with-graphql.html) extensions to effortlessly build APIs around your resources.
