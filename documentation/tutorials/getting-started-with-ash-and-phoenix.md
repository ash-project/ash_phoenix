<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->

# Get Started with Ash and Phoenix

This is a small guide to get you started with Ash & Phoenix.
See the AshPhoenix home page for more information on what is available.

## Setup

To begin, you should go through the Ash [getting started guide](https://hexdocs.pm/ash/get-started.html). You should choose the step
to create a new application with Phoenix pre-installed, as Phoenix cannot
easily be added to your project later.

Once you've done that, you'll have some Ash resources with which to follow the next steps.

## Connecting your Resource to a Phoenix LiveView

In general, working with Ash and Phoenix is fairly "standard" with the exception that you
will be calling into your Ash resources & domains instead of context functions. For that
reason, we suggest reading their documentation as well, since nothing really changes about
controllers, liveviews etc.

### `mix ash_phoenix.gen.live`

We can run `mix ash_phoenix.gen.live` to generate a liveview! Run the following command to
generate a starting point for your own liveview. Remember that it is just a starting point,
not a finished product.

```bash
mix ash_phoenix.gen.live --domain Helpdesk.Support --resource Helpdesk.Support.Ticket
```

Now, start the web server by running `mix phx.server`. Then, visit the tickets route that you added in your browser to see what we have just created.

## Where to Next?

### Examples

- The final chapter's branch for [tunez](https://github.com/sevenseacat/tunez/tree/end-of-chapter-10) from the Ash book is a great example.
- The [Realworld app](https://github.com/team-alembic/realworld) is another good example

### Continue Learning

There's a few places you can go to learn more about how to use ash:

- Read more about how to query the data in your resources - `Ash.Query`
- [Dig deeper into actions.](https://hexdocs.pm/ash/actions.html)
- [Study resource relationship management](https://hexdocs.pm/ash/relationships.html#managing-relationships)

### Ash Authentication & Ash Authentication Phoenix

See the power Ash can bring to your web app or API. [Get authentication working in minutes](https://hexdocs.pm/ash_authentication_phoenix/get-started.html).

### Add an API (or two)

Check out the [AshJsonApi](https://hexdocs.pm/ash_json_api/getting-started-with-ash-json-api.html) and [AshGraphql](https://hexdocs.pm/ash_graphql/getting-started-with-graphql.html) extensions to effortlessly build APIs around your resources.
