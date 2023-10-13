defmodule <%= @app_name %>Web.<%= @resource %>HTML do
  use <%= @app_name %>Web, :html

  embed_templates "<%= @singular %>_html/*"
end
