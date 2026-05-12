defmodule DemoApp do
  @moduledoc """
  Demo Dala application showcasing multiple screens with complex layouts.

  Features demonstrated:
  - Multiple screens with navigation stack
  - Complex layouts (columns, rows, boxes, scroll)
  - Interactive components (buttons, toggles, sliders, text fields)
  - State management across screens
  - Tab bar navigation
  - Modal presentations

  ## How to run:

      cd examples/demo_app
      mix deps.get
      mix dala.deploy --native --ios-sim   # or --android-emu
  """
  use Dala.App

  def navigation(_platform) do
    screens([
      DemoApp.HomeScreen,
      DemoApp.ProfileScreen,
      DemoApp.SettingsScreen,
      DemoApp.FormsScreen
    ])

    tab_bar do
      tab(:home, icon: "house", title: "Home")
      tab(:profile, icon: "person", title: "Profile")
      tab(:settings, icon: "gear", title: "Settings")
    end

    stack(:home, root: DemoApp.HomeScreen)
    stack(:profile, root: DemoApp.ProfileScreen)
    stack(:settings, root: DemoApp.SettingsScreen)
  end

  def on_start do
    {:ok, _pid} = Dala.Screen.start_root(DemoApp.HomeScreen)
    :ok
  end
end
