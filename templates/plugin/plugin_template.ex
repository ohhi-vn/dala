defmodule MyPlugin do
  @moduledoc """
  My custom Dala plugin.

  ## Usage

  Add to your mix.exs:

      def deps do
        [
          {:dala, "~> 0.0.9"},
          {:my_plugin, path: "../my_plugin" }
        ]
      end

  ## Plugin Definition
  """

  use Dala.Plugin,
    schema_version: "1.0.0",
    protocol_version: 3,
    native_api_version: "2.0.0"

  import Dala.Plugin.ComponentDSL

  @doc """
  Define your component schema here.
  """
  component "my_component" do
    # Define properties
    prop("title", :string, required: true)
    prop("count", :integer, default: 0)
    prop("enabled", :bool, default: false)

    # Define events
    event("clicked")
    event("changed", payload: %{value: :integer})

    # Map to native classes
    native("ios", "MyComponentView")
    native("android", "com.myapp.MyComponent")

    # Declare capabilities
    capability(:gestures)
    capability(:accessibility)
  end
end
