defmodule Dala.Designer.ExampleTest do
  @moduledoc """
  Tests for Dala.Designer.Example — validates that all example trees
  are well-formed and can be rendered and converted to code.
  """
  use ExUnit.Case, async: true

  describe "ui_tree/0" do
    test "returns a valid tree structure" do
      tree = Dala.Designer.Example.ui_tree()
      assert is_map(tree)
      assert tree.type == :column
      assert is_map(tree.props)
      assert is_list(tree.children)
      assert length(tree.children) > 0
    end

    test "can be rendered to HTML" do
      tree = Dala.Designer.Example.ui_tree()
      html = Dala.Designer.preview(tree)
      assert html =~ "Dala Designer Example"
      assert html =~ "Tap Me"
      assert html =~ "Another Button"
    end

    test "can be converted to DSL code" do
      tree = Dala.Designer.Example.ui_tree()
      code = Dala.Designer.generate_code(tree, "MyApp.DemoScreen")
      assert code =~ "defmodule MyApp.DemoScreen do"
      assert code =~ "use Dala.Spark.Dsl"
      assert code =~ "column"
      assert code =~ "text"
      assert code =~ "button"
    end

    test "extracts event handlers" do
      tree = Dala.Designer.Example.ui_tree()
      handlers = Dala.Designer.Codegen.extract_handlers(tree)
      assert :button_tapped in handlers
      assert :other_button in handlers
      assert :text_changed in handlers
      assert :toggle_changed in handlers
      assert :slider_changed in handlers
    end

    test "all children have required keys" do
      tree = Dala.Designer.Example.ui_tree()
      Enum.each(tree.children, fn child ->
        assert Map.has_key?(child, :type)
        assert Map.has_key?(child, :props)
        assert Map.has_key?(child, :children)
      end)
    end

    test "nested children have required keys" do
      tree = Dala.Designer.Example.ui_tree()
      # The row has children (buttons)
      row = Enum.find(tree.children, &(&1.type == :row))
      assert row != nil
      Enum.each(row.children, fn child ->
        assert Map.has_key?(child, :type)
        assert Map.has_key?(child, :props)
        assert Map.has_key?(child, :children)
      end)
    end
  end

  describe "login_screen/0" do
    test "returns a valid tree structure" do
      tree = Dala.Designer.Example.login_screen()
      assert tree.type == :column
      assert is_list(tree.children)
    end

    test "can be rendered to HTML" do
      tree = Dala.Designer.Example.login_screen()
      html = Dala.Designer.preview(tree)
      assert html =~ "Welcome Back"
      assert html =~ "Sign In"
      assert html =~ "Forgot password?"
      assert html =~ "Sign Up"
    end

    test "can be converted to DSL code" do
      tree = Dala.Designer.Example.login_screen()
      code = Dala.Designer.generate_code(tree, "MyApp.LoginScreen")
      assert code =~ "defmodule MyApp.LoginScreen do"
      assert code =~ "screen name: :login_screen"
    end

    test "extracts login event handlers" do
      tree = Dala.Designer.Example.login_screen()
      handlers = Dala.Designer.Codegen.extract_handlers(tree)
      assert :email_changed in handlers
      assert :password_changed in handlers
      assert :sign_in in handlers
    end

    test "has email and password fields" do
      tree = Dala.Designer.Example.login_screen()
      types = collect_types(tree)
      assert :text_field in types
      assert length(Enum.filter(tree.children, &(&1.type == :text_field))) == 2
    end
  end

  describe "settings_screen/0" do
    test "returns a valid tree structure" do
      tree = Dala.Designer.Example.settings_screen()
      assert tree.type == :column
      assert is_list(tree.children)
    end

    test "can be rendered to HTML" do
      tree = Dala.Designer.Example.settings_screen()
      html = Dala.Designer.preview(tree)
      assert html =~ "Settings"
      assert html =~ "Notifications"
      assert html =~ "Dark Mode"
      assert html =~ "Volume"
      assert html =~ "Sign Out"
    end

    test "can be converted to DSL code" do
      tree = Dala.Designer.Example.settings_screen()
      code = Dala.Designer.generate_code(tree, "MyApp.SettingsScreen")
      assert code =~ "defmodule MyApp.SettingsScreen do"
      assert code =~ "screen name: :settings_screen"
    end

    test "extracts settings event handlers" do
      tree = Dala.Designer.Example.settings_screen()
      handlers = Dala.Designer.Codegen.extract_handlers(tree)
      assert :notifications_toggled in handlers
      assert :dark_mode_toggled in handlers
      assert :volume_changed in handlers
      assert :sign_out in handlers
    end

    test "has toggle components" do
      tree = Dala.Designer.Example.settings_screen()
      types = collect_types(tree)
      assert :toggle in types
    end

    test "has slider for volume" do
      tree = Dala.Designer.Example.settings_screen()
      types = collect_types(tree)
      assert :slider in types
    end
  end

  describe "all examples round-trip" do
    test "ui_tree round-trips through code gen and back" do
      tree = Dala.Designer.Example.ui_tree()
      code = Dala.Designer.generate_code(tree, "MyApp.RoundTrip")
      # The generated code should contain all the component types
      assert code =~ "column"
      assert code =~ "row"
      assert code =~ "text"
      assert code =~ "button"
      assert code =~ "text_field"
      assert code =~ "toggle"
      assert code =~ "slider"
    end

    test "login_screen round-trips through code gen" do
      tree = Dala.Designer.Example.login_screen()
      code = Dala.Designer.generate_code(tree, "MyApp.Login")
      assert code =~ "text"
      assert code =~ "text_field"
      assert code =~ "button"
      assert code =~ "row"
      assert code =~ "spacer"
    end

    test "settings_screen round-trips through code gen" do
      tree = Dala.Designer.Example.settings_screen()
      code = Dala.Designer.generate_code(tree, "MyApp.Settings")
      assert code =~ "row"
      assert code =~ "text"
      assert code =~ "icon"
      assert code =~ "divider"
      assert code =~ "toggle"
      assert code =~ "slider"
      assert code =~ "button"
    end
  end

  # ── Helpers ─────────────────────────────────────────────────────────────────

  defp collect_types(%{type: type, children: children}) do
    child_types = Enum.flat_map(children, &collect_types/1)
    [type | child_types]
  end
end
