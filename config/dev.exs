import Config

config :ash_phoenix, DemoWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: DemoWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: StapleUi.PubSub,
  live_view: [signing_salt: "mwTS8kFY"],
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  debug_errors: true,
  secret_key_base: "+tJsp8UPKEKINkzDxs9m3W1kbC+w5noWeCVtniUhUBftqg/i4vM1I/5KdbvFieYt",
  server: true

config :ash_phoenix, ash_apis: [Demo.Accounts]

config :ash_authentication, AshAuthentication.JsonWebToken,
  signing_secret: "All I wanna do is to thank you, even though I don't know who you are."
