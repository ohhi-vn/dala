defmodule Dala.ThemeTest do
  @moduledoc """
  Tests for Dala.Theme public API — resolve, set_accent, prefers_reduced_motion,
  line_height_map, and Adaptive.Custom.
  """
  use ExUnit.Case, async: true

  alias Dala.Theme.Theme

  setup do
    original = Dala.Theme.current()
    on_exit(fn -> Dala.Theme.set(original) end)
    :ok
  end

  describe "resolve/1" do
    test "resolves color tokens to values" do
      primary = Dala.Theme.resolve(:primary)
      assert primary != nil
    end

    test "resolves spacing tokens to pixel values" do
      assert Dala.Theme.resolve(:space_xs) == 4
      assert Dala.Theme.resolve(:space_sm) == 8
      assert Dala.Theme.resolve(:space_md) == 16
      assert Dala.Theme.resolve(:space_lg) == 24
      assert Dala.Theme.resolve(:space_xl) == 32
    end

    test "resolves radius tokens" do
      assert Dala.Theme.resolve(:radius_sm) == 6
      assert Dala.Theme.resolve(:radius_md) == 10
      assert Dala.Theme.resolve(:radius_lg) == 16
      assert Dala.Theme.resolve(:radius_pill) == 100
    end

    test "returns nil for unknown tokens" do
      assert Dala.Theme.resolve(:nonexistent_token) == nil
    end

    test "reflects theme overrides" do
      Dala.Theme.set(primary: 0xFF00FF00)
      assert Dala.Theme.resolve(:primary) == 0xFF00FF00
    end
  end

  describe "set_accent/1" do
    test "overrides primary with raw integer color" do
      Dala.Theme.set_accent(0xFFFF0000)
      theme = Dala.Theme.current()
      assert theme.primary == 0xFFFF0000
    end

    test "auto-selects on_primary for dark colors" do
      Dala.Theme.set_accent(0xFF000000)
      theme = Dala.Theme.current()
      assert theme.on_primary == 0xFFFFFFFF
    end

    test "auto-selects on_primary for light colors" do
      Dala.Theme.set_accent(0xFFFFFFFF)
      theme = Dala.Theme.current()
      assert theme.on_primary == 0xFF0F0F0F
    end

    test "preserves other theme tokens" do
      original = Dala.Theme.current()
      Dala.Theme.set_accent(0xFF00FF00)
      updated = Dala.Theme.current()
      assert updated.surface == original.surface
      assert updated.background == original.background
      assert updated.error == original.error
    end
  end

  describe "prefers_reduced_motion/0" do
    test "returns a boolean" do
      result = Dala.Theme.prefers_reduced_motion()
      assert is_boolean(result)
    end
  end

  describe "line_height_map/1" do
    test "returns line height tokens" do
      theme = Dala.Theme.current()
      lh = Theme.line_height_map(theme)
      assert lh.line_height_tight == 1.25
      assert lh.line_height_normal == 1.5
      assert lh.line_height_relaxed == 1.75
    end
  end

  describe "Adaptive.Custom" do
    test "new/1 creates struct with defaults" do
      custom = Dala.Theme.Adaptive.Custom.new([])
      assert custom.dark == Dala.Theme.Dark
      assert custom.light == Dala.Theme.Light
    end

    test "new/1 accepts custom dark/light modules" do
      custom = Dala.Theme.Adaptive.Custom.new(dark: Dala.Theme.Obsidian, light: Dala.Theme.Birch)
      assert custom.dark == Dala.Theme.Obsidian
      assert custom.light == Dala.Theme.Birch
    end

    test "theme/1 returns a Dala.Theme.t()" do
      custom = Dala.Theme.Adaptive.Custom.new([])
      theme = Dala.Theme.Adaptive.Custom.theme(custom)
      assert %Dala.Theme.Theme{} = theme
    end
  end
end
