defmodule Dala.Designer.RenderTest do
  @moduledoc """
  Tests for Dala.Designer static HTML rendering — component coverage,
  style generation, tree inspector, and edge cases.
  """
  use ExUnit.Case, async: true

  describe "new component rendering" do
    test "renders card component" do
      ui_tree = %{
        type: :card,
        props: %{variant: :elevated, elevation: 2, corner_radius: 12, padding: :md},
        children: [%{type: :text, props: %{text: "Card content"}, children: []}]
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-card"
      assert html =~ "Card content"
    end

    test "renders checkbox component" do
      ui_tree = %{
        type: :checkbox,
        props: %{value: true, label: "Accept terms"},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-checkbox"
    end

    test "renders radio component" do
      ui_tree = %{
        type: :radio,
        props: %{selected: false, label: "Option A"},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-radio"
    end

    test "renders chip component" do
      ui_tree = %{
        type: :chip,
        props: %{label: "Filter", variant: :filter},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-chip"
    end

    test "renders fab component" do
      ui_tree = %{
        type: :fab,
        props: %{icon: :add},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-fab"
    end

    test "renders icon_button component" do
      ui_tree = %{
        type: :icon_button,
        props: {:icon, :heart},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-icon-button"
    end

    test "renders app_bar component" do
      ui_tree = %{
        type: :app_bar,
        props: %{title: "My App"},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-app-bar"
    end

    test "renders search_bar component" do
      ui_tree = %{
        type: :search_bar,
        props: %{placeholder: "Search..."},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-search-bar"
    end

    test "renders snackbar component" do
      ui_tree = %{
        type: :snackbar,
        props: %{message: "Saved!", visible: true},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-snackbar"
    end

    test "renders carousel component" do
      ui_tree = %{
        type: :carousel,
        props: %{},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-carousel"
    end

    test "renders badge component" do
      ui_tree = %{
        type: :badge,
        props: %{count: 5},
        children: [%{type: :icon, props: %{name: :notifications}, children: []}]
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-badge"
    end

    test "renders bottom_sheet component" do
      ui_tree = %{
        type: :bottom_sheet,
        props: %{visible: true},
        children: [%{type: :text, props: %{text: "Sheet content"}, children: []}]
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-bottom-sheet"
    end

    test "renders tooltip component" do
      ui_tree = %{
        type: :tooltip,
        props: %{text: "Help text"},
        children: [%{type: :icon, props: %{name: :help}, children: []}]
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-tooltip"
    end

    test "renders nav_bar component" do
      ui_tree = %{
        type: :nav_bar,
        props: %{},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-nav-bar"
    end

    test "renders nav_drawer component" do
      ui_tree = %{
        type: :nav_drawer,
        props: %{open: true},
        children: [%{type: :text, props: %{text: "Drawer"}, children: []}]
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-nav-drawer"
    end

    test "renders nav_rail component" do
      ui_tree = %{
        type: :nav_rail,
        props: %{},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-nav-rail"
    end

    test "renders segmented_button component" do
      ui_tree = %{
        type: :segmented_button,
        props: %{options: ["Day", "Week", "Month"]},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-segmented-button"
    end

    test "renders menu component" do
      ui_tree = %{
        type: :menu,
        props: %{open: false},
        children: [%{type: :text, props: %{text: "Menu"}, children: []}]
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-menu"
    end

    test "renders date_picker component" do
      ui_tree = %{
        type: :date_picker,
        props: %{value: "2025-01-01"},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-date-picker"
    end

    test "renders time_picker component" do
      ui_tree = %{
        type: :time_picker,
        props: %{value: "12:00"},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-time-picker"
    end
  end

  describe "style generation" do
    test "generates padding styles from atom values" do
      ui_tree = %{
        type: :column,
        props: %{padding: :md},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "padding"
    end

    test "generates gap styles" do
      ui_tree = %{
        type: :column,
        props: %{gap: :sm},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "gap"
    end

    test "generates background color" do
      ui_tree = %{
        type: :box,
        props: %{background: :surface},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "background"
    end

    test "generates corner_radius" do
      ui_tree = %{
        type: :box,
        props: %{corner_radius: :radius_md},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "border-radius"
    end

    test "generates width and height" do
      ui_tree = %{
        type: :box,
        props: %{width: 100, height: 200},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "width"
      assert html =~ "height"
    end

    test "generates text_size styles" do
      ui_tree = %{
        type: :text,
        props: %{text: "Hello", text_size: :xl},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "font-size"
    end

    test "generates text_color styles" do
      ui_tree = %{
        type: :text,
        props: %{text: "Hello", text_color: :primary},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "color"
    end

    test "generates font_weight" do
      ui_tree = %{
        type: :text,
        props: %{text: "Bold", font_weight: :bold},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "font-weight"
    end

    test "generates text_align" do
      ui_tree = %{
        type: :text,
        props: %{text: "Centered", text_align: :center},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "text-align"
    end

    test "generates border styles" do
      ui_tree = %{
        type: :box,
        props: %{border_color: :primary, border_width: 2},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "border"
    end
  end

  describe "CSS value conversion" do
    test "converts space_xs to pixels" do
      ui_tree = %{type: :column, props: %{padding: :space_xs}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "4px"
    end

    test "converts space_sm to pixels" do
      ui_tree = %{type: :column, props: %{padding: :space_sm}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "8px"
    end

    test "converts space_md to pixels" do
      ui_tree = %{type: :column, props: %{padding: :space_md}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "16px"
    end

    test "converts space_lg to pixels" do
      ui_tree = %{type: :column, props: %{padding: :space_lg}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "24px"
    end

    test "converts space_xl to pixels" do
      ui_tree = %{type: :column, props: %{padding: :space_xl}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "32px"
    end

    test "converts radius_sm to pixels" do
      ui_tree = %{type: :box, props: %{corner_radius: :radius_sm}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "4px"
    end

    test "converts radius_md to pixels" do
      ui_tree = %{type: :box, props: %{corner_radius: :radius_md}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "8px"
    end

    test "converts radius_lg to pixels" do
      ui_tree = %{type: :box, props: %{corner_radius: :radius_lg}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "16px"
    end

    test "converts radius_pill to 999px" do
      ui_tree = %{type: :box, props: %{corner_radius: :radius_pill}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "999px"
    end

    test "converts primary color" do
      ui_tree = %{type: :text, props: %{text: "Hi", text_color: :primary}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "#6750A4"
    end

    test "converts surface color" do
      ui_tree = %{type: :box, props: %{background: :surface}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "#FFFBFE"
    end

    test "converts on_surface color" do
      ui_tree = %{type: :text, props: %{text: "Hi", text_color: :on_surface}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "#1C1B1F"
    end

    test "converts on_primary color" do
      ui_tree = %{type: :text, props: %{text: "Hi", text_color: :on_primary}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "#FFFFFF"
    end

    test "converts text_size xl to 24px" do
      ui_tree = %{type: :text, props: %{text: "Hi", text_size: :xl}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "24px"
    end

    test "converts text_size lg to 18px" do
      ui_tree = %{type: :text, props: %{text: "Hi", text_size: :lg}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "18px"
    end

    test "converts text_size md to 14px" do
      ui_tree = %{type: :text, props: %{text: "Hi", text_size: :md}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "14px"
    end

    test "converts text_size sm to 12px" do
      ui_tree = %{type: :text, props: %{text: "Hi", text_size: :sm}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "12px"
    end

    test "converts text_size xs to 10px" do
      ui_tree = %{type: :text, props: %{text: "Hi", text_size: :xs}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "10px"
    end
  end

  describe "tree inspector" do
    test "includes tree inspector by default" do
      ui_tree = %{type: :text, props: %{text: "Test"}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "tree-inspector"
    end

    test "can hide tree inspector" do
      ui_tree = %{type: :text, props: %{text: "Test"}, children: []}
      html = Dala.Designer.preview(ui_tree, show_tree: false)
      refute html =~ "tree-inspector"
    end

    test "tree inspector shows component types" do
      ui_tree = %{
        type: :column,
        props: %{},
        children: [
          %{type: :text, props: %{text: "Hello"}, children: []}
        ]
      }

      html = Dala.Designer.preview(ui_tree, show_tree: true)
      assert html =~ "column"
      assert html =~ "text"
    end
  end

  describe "interactive JavaScript" do
    test "includes tap event handling" do
      ui_tree = %{type: :button, props: %{text: "Test", on_tap: :test}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "on-tap"
    end

    test "includes toggle event handling" do
      ui_tree = %{type: :toggle, props: %{on_tap: :toggle}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "data-toggle"
    end

    test "includes slider event handling" do
      ui_tree = %{type: :slider, props: %{value: 50, on_change: :slide}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "data-slider"
    end

    test "includes text input event handling" do
      ui_tree = %{type: :text_field, props: %{on_change: :input}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "data-text-input"
    end

    test "includes draggable handling" do
      ui_tree = %{type: :box, props: %{draggable: :drag}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "data-draggable"
    end

    test "includes droppable handling" do
      ui_tree = %{type: :box, props: %{droppable: :drop}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "data-droppable"
    end

    test "includes long press handling" do
      ui_tree = %{type: :box, props: %{on_long_press: :long}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "data-on-long-press"
    end

    test "includes swipe handling" do
      ui_tree = %{type: :box, props: %{on_swipe: :swipe}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "data-on-swipe"
    end

    test "logEvent function is defined" do
      ui_tree = %{type: :text, props: %{text: "Test"}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "logEvent"
    end
  end

  describe "HTML escaping" do
    test "escapes ampersands in text" do
      ui_tree = %{type: :text, props: %{text: "A & B"}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "&amp;"
    end

    test "escapes quotes in text" do
      ui_tree = %{type: :text, props: %{text: ~s(He said "hello")}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "&quot;"
    end

    test "escapes less-than in text" do
      ui_tree = %{type: :text, props: %{text: "1 < 2"}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "&lt;"
    end

    test "escapes greater-than in text" do
      ui_tree = %{type: :text, props: %{text: "2 > 1"}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "&gt;"
    end

    test "escapes HTML in placeholder" do
      ui_tree = %{type: :text_field, props: %{placeholder: "<script>alert(1)</script>"}, children: []}
      html = Dala.Designer.preview(ui_tree)
      refute html =~ "<script>alert(1)</script>"
    end

    test "escapes HTML in tree inspector" do
      ui_tree = %{type: :text, props: %{text: "<b>bold</b>"}, children: []}
      html = Dala.Designer.preview(ui_tree, show_tree: true)
      assert html =~ "&lt;b&gt;bold&lt;/b&gt;"
    end
  end

  describe "options" do
    test "custom title" do
      ui_tree = %{type: :text, props: %{text: "Test"}, children: []}
      html = Dala.Designer.preview(ui_tree, title: "My Custom Title")
      assert html =~ "<title>My Custom Title</title>"
    end

    test "default title" do
      ui_tree = %{type: :text, props: %{text: "Test"}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "<title>"
    end
  end

  describe "edge cases" do
    test "handles nil tree" do
      html = Dala.Designer.preview(nil)
      assert html =~ "<!DOCTYPE html>"
    end

    test "handles empty map tree" do
      html = Dala.Designer.preview(%{})
      assert html =~ "<!DOCTYPE html>"
    end

    test "handles tree with nil type" do
      html = Dala.Designer.preview(%{type: nil})
      assert html =~ "<!DOCTYPE html>"
    end

    test "handles very deep nesting" do
      tree = Enum.reduce(1..10, %{type: :text, props: %{text: "Deep"}, children: []}, fn _, acc ->
        %{type: :column, props: %{}, children: [acc]}
      end)
      html = Dala.Designer.preview(tree)
      assert html =~ "Deep"
    end

    test "handles tree with many siblings" do
      children = for i <- 1..50, do: %{type: :text, props: %{text: "Item #{i}"}, children: []}
      tree = %{type: :column, props: %{}, children: children}
      html = Dala.Designer.preview(tree)
      assert html =~ "Item 1"
      assert html =~ "Item 50"
    end

    test "handles unicode text" do
      ui_tree = %{type: :text, props: %{text: "Hello 世界 🌍"}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "Hello 世界 🌍"
    end

    test "handles empty string text" do
      ui_tree = %{type: :text, props: %{text: ""}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "<!DOCTYPE html>"
    end

    test "handles mixed string and atom keys" do
      ui_tree = %{
        "type" => :column,
        "props" => %{},
        "children" => [
          %{type: :text, "props" => %{"text" => "Mixed"}, children: []}
        ]
      }
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "Mixed"
    end
  end

  describe "container components" do
    test "renders scroll container" do
      ui_tree = %{
        type: :scroll,
        props: %{},
        children: [
          %{type: :text, props: %{text: "Scrollable content"}, children: []}
        ]
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-scroll"
    end

    test "renders modal container" do
      ui_tree = %{
        type: :modal,
        props: %{visible: true},
        children: [
          %{type: :text, props: %{text: "Modal content"}, children: []}
        ]
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-modal"
    end

    test "renders pressable container" do
      ui_tree = %{
        type: :pressable,
        props: %{},
        children: [
          %{type: :text, props: %{text: "Press me"}, children: []}
        ]
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-pressable"
    end

    test "renders safe_area container" do
      ui_tree = %{
        type: :safe_area,
        props: %{},
        children: [
          %{type: :text, props: %{text: "Safe content"}, children: []}
        ]
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-safe-area"
    end
  end

  describe "media components" do
    test "renders image component" do
      ui_tree = %{
        type: :image,
        props: %{source: "https://example.com/image.png", width: 100, height: 100},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-image"
      assert html =~ "https://example.com/image.png"
    end

    test "renders video component" do
      ui_tree = %{
        type: :video,
        props: %{source: "https://example.com/video.mp4"},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-video"
    end

    test "renders activity_indicator" do
      ui_tree = %{type: :activity_indicator, props: %{}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-activity-indicator"
    end

    test "renders progress_bar with value" do
      ui_tree = %{type: :progress_bar, props: %{value: 0.75}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-progress-bar"
    end

    test "renders webview" do
      ui_tree = %{
        type: :webview,
        props: %{url: "https://example.com"},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-webview"
    end

    test "renders camera_preview" do
      ui_tree = %{type: :camera_preview, props: %{}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-camera-preview"
    end

    test "renders native_view" do
      ui_tree = %{type: :native_view, props: %{}, children: []}
      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-native-view"
    end
  end

  describe "v0.8 new components" do
    test "renders skeleton component" do
      ui_tree = %{
        type: :skeleton,
        props: %{width: 200, height: 16, corner_radius: :radius_sm},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-skeleton"
      assert html =~ "width: 200px"
      assert html =~ "height: 16px"
    end

    test "renders skeleton with fill width" do
      ui_tree = %{
        type: :skeleton,
        props: %{width: :fill, height: 120},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-skeleton"
      assert html =~ "width: 100%"
    end

    test "renders empty_state component" do
      ui_tree = %{
        type: :empty_state,
        props: %{icon: "inbox", title: "Nothing here", message: "Items appear here", action_label: "Get started"},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-empty-state"
      assert html =~ "Nothing here"
      assert html =~ "Items appear here"
      assert html =~ "Get started"
    end

    test "renders avatar component" do
      ui_tree = %{
        type: :avatar,
        props: %{src: "https://example.com/photo.jpg", fallback: "JS", size: 48, shape: :circle},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-avatar"
      assert html =~ "48px"
    end

    test "renders avatar with fallback" do
      ui_tree = %{
        type: :avatar,
        props: %{fallback: "AB", size: 40},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-avatar"
      assert html =~ "AB"
    end

    test "renders stepper component" do
      ui_tree = %{
        type: :stepper,
        props: %{steps: ["Account", "Profile", "Done"], current: 1},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-stepper"
      assert html =~ "Account"
      assert html =~ "Profile"
      assert html =~ "Done"
    end

    test "renders grid container" do
      ui_tree = %{
        type: :grid,
        props: %{columns: 2, gap: :space_sm, padding: :space_md},
        children: [
          %{type: :text, props: %{text: "Cell 1"}, children: []},
          %{type: :text, props: %{text: "Cell 2"}, children: []}
        ]
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "dala-grid"
      assert html =~ "grid-template-columns: repeat(2, 1fr)"
      assert html =~ "Cell 1"
      assert html =~ "Cell 2"
    end

    test "renders grid with 3 columns" do
      ui_tree = %{
        type: :grid,
        props: %{columns: 3},
        children: []
      }

      html = Dala.Designer.preview(ui_tree)
      assert html =~ "repeat(3, 1fr)"
    end
  end
end
