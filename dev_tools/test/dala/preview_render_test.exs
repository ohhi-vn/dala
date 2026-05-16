defmodule Dala.Preview.RenderTest do
  @moduledoc """
  Tests for Dala.Preview static HTML rendering — component coverage,
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

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-card"
      assert html =~ "Card content"
    end

    test "renders checkbox component" do
      ui_tree = %{
        type: :checkbox,
        props: %{value: true, label: "Accept terms"},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-checkbox"
    end

    test "renders radio component" do
      ui_tree = %{
        type: :radio,
        props: %{selected: true, label: "Option A", group: "choices"},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-radio"
    end

    test "renders chip component" do
      ui_tree = %{
        type: :chip,
        props: %{label: "Filter", variant: :filter, selected: true},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-chip"
    end

    test "renders fab component" do
      ui_tree = %{
        type: :fab,
        props: %{icon: :edit, text: "Compose"},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-fab"
    end

    test "renders icon_button component" do
      ui_tree = %{
        type: :icon_button,
        props: %{icon: :favorite, selected: false},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-icon-button"
    end

    test "renders app_bar component" do
      ui_tree = %{
        type: :app_bar,
        props: %{title: "My App", leading_icon: :menu, on_leading: :menu_tapped},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-app-bar"
    end

    test "renders search_bar component" do
      ui_tree = %{
        type: :search_bar,
        props: %{placeholder: "Search...", on_change: :search_changed},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-search-bar"
    end

    test "renders snackbar component" do
      ui_tree = %{
        type: :snackbar,
        props: %{message: "Item deleted", action_label: "Undo", visible: true, on_action: :undo},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-snackbar"
    end

    test "renders carousel component" do
      ui_tree = %{
        type: :carousel,
        props: %{loop: true, autoplay: false},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-carousel"
    end

    test "renders badge component" do
      ui_tree = %{
        type: :badge,
        props: %{count: 5},
        children: [%{type: :icon, props: %{name: :notifications}, children: []}]
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-badge"
    end

    test "renders bottom_sheet component" do
      ui_tree = %{
        type: :bottom_sheet,
        props: %{visible: true, height: 300},
        children: [%{type: :text, props: %{text: "Sheet content"}, children: []}]
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-bottom_sheet"
    end

    test "renders tooltip component" do
      ui_tree = %{
        type: :tooltip,
        props: %{text: "Helpful info", position: :top, visible: false},
        children: [%{type: :icon, props: %{name: :help}, children: []}]
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-tooltip"
    end

    test "renders nav_bar component" do
      ui_tree = %{
        type: :nav_bar,
        props: %{active: "home", on_select: :tab_changed},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-nav-bar"
    end

    test "renders nav_drawer component" do
      ui_tree = %{
        type: :nav_drawer,
        props: %{visible: true, active: "home", on_dismiss: :dismissed},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-nav-drawer"
    end

    test "renders nav_rail component" do
      ui_tree = %{
        type: :nav_rail,
        props: %{active: "dashboard", on_select: :nav_changed},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-nav-rail"
    end

    test "renders segmented_button component" do
      ui_tree = %{
        type: :segmented_button,
        props: %{selected: "week", on_select: :range_changed},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-segmented-button"
    end

    test "renders menu component" do
      ui_tree = %{
        type: :menu,
        props: %{visible: true, on_select: :menu_selected},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-menu"
    end

    test "renders date_picker component" do
      ui_tree = %{
        type: :date_picker,
        props: %{visible: true, selected_date: "2025-01-15", on_select: :date_picked},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-date-picker"
    end

    test "renders time_picker component" do
      ui_tree = %{
        type: :time_picker,
        props: %{visible: true, selected_time: "09:30", on_select: :time_picked},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-time-picker"
    end
  end

  describe "style generation" do
    test "generates padding styles from atom values" do
      ui_tree = %{
        type: :column,
        props: %{padding: :space_md},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "padding"
    end

    test "generates gap styles" do
      ui_tree = %{
        type: :row,
        props: %{gap: :space_sm},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "gap"
    end

    test "generates background color" do
      ui_tree = %{
        type: :box,
        props: %{background: :surface},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "background"
    end

    test "generates corner_radius" do
      ui_tree = %{
        type: :card,
        props: %{corner_radius: 12},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "border-radius"
    end

    test "generates width and height" do
      ui_tree = %{
        type: :box,
        props: %{width: 200, height: 100},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "width"
      assert html =~ "height"
    end

    test "generates text_size styles" do
      ui_tree = %{
        type: :text,
        props: %{text: "Big", text_size: :xl},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "font-size"
    end

    test "generates text_color styles" do
      ui_tree = %{
        type: :text,
        props: %{text: "Colored", text_color: :primary},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "color"
    end

    test "generates font_weight" do
      ui_tree = %{
        type: :text,
        props: %{text: "Bold", font_weight: :bold},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "font-weight"
    end

    test "generates text_align" do
      ui_tree = %{
        type: :text,
        props: %{text: "Centered", text_align: :center},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "text-align"
    end

    test "generates border styles" do
      ui_tree = %{
        type: :box,
        props: %{border_color: :primary, border_width: 2},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "border-color"
      assert html =~ "border-width"
    end
  end

  describe "CSS value conversion" do
    test "converts space_xs to pixels" do
      ui_tree = %{type: :column, props: %{padding: :space_xs}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "4px"
    end

    test "converts space_sm to pixels" do
      ui_tree = %{type: :column, props: %{padding: :space_sm}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "8px"
    end

    test "converts space_md to pixels" do
      ui_tree = %{type: :column, props: %{padding: :space_md}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "16px"
    end

    test "converts space_lg to pixels" do
      ui_tree = %{type: :column, props: %{padding: :space_lg}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "24px"
    end

    test "converts space_xl to pixels" do
      ui_tree = %{type: :column, props: %{padding: :space_xl}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "32px"
    end

    test "converts radius_sm to pixels" do
      ui_tree = %{type: :card, props: %{corner_radius: :radius_sm}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "4px"
    end

    test "converts radius_md to pixels" do
      ui_tree = %{type: :card, props: %{corner_radius: :radius_md}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "8px"
    end

    test "converts radius_lg to pixels" do
      ui_tree = %{type: :card, props: %{corner_radius: :radius_lg}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "12px"
    end

    test "converts radius_pill to 999px" do
      ui_tree = %{type: :card, props: %{corner_radius: :radius_pill}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "999px"
    end

    test "converts primary color" do
      ui_tree = %{type: :text, props: %{text: "Hi", text_color: :primary}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "#2196F3"
    end

    test "converts surface color" do
      ui_tree = %{type: :box, props: %{background: :surface}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "#FFFFFF"
    end

    test "converts on_surface color" do
      ui_tree = %{type: :text, props: %{text: "Hi", text_color: :on_surface}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "#212121"
    end

    test "converts on_primary color" do
      ui_tree = %{type: :button, props: %{text: "Hi", text_color: :on_primary}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "#FFFFFF"
    end

    test "converts text_size xl to 24px" do
      ui_tree = %{type: :text, props: %{text: "Hi", text_size: :xl}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "24px"
    end

    test "converts text_size lg to 18px" do
      ui_tree = %{type: :text, props: %{text: "Hi", text_size: :lg}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "18px"
    end

    test "converts text_size md to 14px" do
      ui_tree = %{type: :text, props: %{text: "Hi", text_size: :md}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "14px"
    end

    test "converts text_size sm to 12px" do
      ui_tree = %{type: :text, props: %{text: "Hi", text_size: :sm}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "12px"
    end

    test "converts text_size xs to 10px" do
      ui_tree = %{type: :text, props: %{text: "Hi", text_size: :xs}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "10px"
    end
  end

  describe "tree inspector" do
    test "includes tree inspector by default" do
      ui_tree = %{type: :text, props: %{text: "Test"}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "tree-inspector"
      assert html =~ "Component Tree"
    end

    test "can hide tree inspector" do
      ui_tree = %{type: :text, props: %{text: "Test"}, children: []}
      html = Dala.Preview.preview(ui_tree, show_tree: false)
      refute html =~ "tree-inspector"
    end

    test "tree inspector shows component types" do
      ui_tree = %{
        type: :column,
        props: %{},
        children: [
          %{type: :text, props: %{text: "Hello"}, children: []},
          %{type: :button, props: %{text: "Go"}, children: []}
        ]
      }

      html = Dala.Preview.preview(ui_tree, show_tree: true)
      assert html =~ "column"
      assert html =~ "text"
      assert html =~ "button"
    end
  end

  describe "interactive JavaScript" do
    test "includes tap event handling" do
      ui_tree = %{type: :button, props: %{text: "Tap", on_tap: :my_tap}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "data-on-tap"
      assert html =~ "my_tap"
    end

    test "includes toggle event handling" do
      ui_tree = %{type: :toggle, props: %{on_tap: :my_toggle}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "data-toggle"
      assert html =~ "my_toggle"
    end

    test "includes slider event handling" do
      ui_tree = %{type: :slider, props: %{value: 50, on_change: :my_slider}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "data-slider"
      assert html =~ "my_slider"
    end

    test "includes text input event handling" do
      ui_tree = %{type: :text_field, props: %{on_change: :my_input}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "data-text-input"
      assert html =~ "my_input"
    end

    test "includes draggable handling" do
      ui_tree = %{type: :box, props: %{draggable: :my_drag}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "data-draggable"
      assert html =~ "my_drag"
    end

    test "includes droppable handling" do
      ui_tree = %{type: :box, props: %{droppable: :my_drop}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "data-droppable"
      assert html =~ "my_drop"
    end

    test "includes long press handling" do
      ui_tree = %{type: :box, props: %{on_long_press: :my_long}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "data-on-long-press"
      assert html =~ "my_long"
    end

    test "includes swipe handling" do
      ui_tree = %{type: :box, props: %{on_swipe: :my_swipe}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "data-on-swipe"
      assert html =~ "my_swipe"
    end

    test "logEvent function is defined" do
      ui_tree = %{type: :text, props: %{text: "Test"}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "logEvent"
      assert html =~ "event-log"
    end
  end

  describe "HTML escaping" do
    test "escapes ampersands in text" do
      ui_tree = %{type: :text, props: %{text: "A & B"}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "A &amp; B"
    end

    test "escapes quotes in text" do
      ui_tree = %{type: :text, props: %{text: ~s(He said "hello")}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "&quot;"
    end

    test "escapes less-than in text" do
      ui_tree = %{type: :text, props: %{text: "1 < 2"}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "&lt;"
    end

    test "escapes greater-than in text" do
      ui_tree = %{type: :text, props: %{text: "2 > 1"}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "&gt;"
    end

    test "escapes HTML in placeholder" do
      ui_tree = %{type: :text_field, props: %{placeholder: "<script>"}, children: []}
      html = Dala.Preview.preview(ui_tree)
      # The page template includes legitimate <script> tags (Alpine.js, event logger),
      # so we check the placeholder attribute specifically contains escaped HTML
      assert html =~ "placeholder=\"&lt;script&gt;\""
      refute html =~ "placeholder=\"<script>\""
    end

    test "escapes HTML in tree inspector" do
      ui_tree = %{type: :text, props: %{text: "<b>bold</b>"}, children: []}
      html = Dala.Preview.preview(ui_tree, show_tree: true)
      assert html =~ "&lt;b&gt;bold&lt;/b&gt;"
    end
  end

  describe "options" do
    test "custom title" do
      ui_tree = %{type: :text, props: %{text: "Test"}, children: []}
      html = Dala.Preview.preview(ui_tree, title: "Custom Title")
      assert html =~ "<title>Custom Title</title>"
    end

    test "default title" do
      ui_tree = %{type: :text, props: %{text: "Test"}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "Dala UI Preview - Interactive Simulation Dev Tool"
    end
  end

  describe "edge cases" do
    test "handles nil tree" do
      html = Dala.Preview.preview(nil)
      assert html =~ "Dala UI Preview"
    end

    test "handles empty map tree" do
      html = Dala.Preview.preview(%{})
      assert html =~ "Dala UI Preview"
    end

    test "handles tree with nil type" do
      html = Dala.Preview.preview(%{type: nil, props: %{}, children: []})
      assert html =~ "Dala UI Preview"
    end

    test "handles very deep nesting" do
      # Build a deeply nested tree
      tree = Enum.reduce(1..20, %{type: :text, props: %{text: "Deep"}, children: []}, fn _, acc ->
        %{type: :column, props: %{}, children: [acc]}
      end)

      html = Dala.Preview.preview(tree)
      assert html =~ "Deep"
    end

    test "handles tree with many siblings" do
      children = for i <- 1..50 do
        %{type: :text, props: %{text: "Item #{i}"}, children: []}
      end

      html = Dala.Preview.preview(%{type: :column, props: %{}, children: children})
      assert html =~ "Item 1"
      assert html =~ "Item 50"
    end

    test "handles unicode text" do
      ui_tree = %{type: :text, props: %{text: "Hello 世界 🌍"}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "Hello 世界 🌍"
    end

    test "handles empty string text" do
      ui_tree = %{type: :text, props: %{text: ""}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-text"
    end

    test "handles mixed string and atom keys" do
      ui_tree = %{
        "type" => :column,
        "children" => [
          %{"props" => %{text: "Mixed"}, "type" => :text, "children" => []}
        ],
        props: %{padding: :md}
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "Mixed"
    end
  end

  describe "container components" do
    test "renders scroll container" do
      ui_tree = %{
        type: :scroll,
        props: %{padding: :md},
        children: [%{type: :text, props: %{text: "Scrollable"}, children: []}]
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-scroll"
      assert html =~ "Scrollable"
    end

    test "renders modal container" do
      ui_tree = %{
        type: :modal,
        props: %{on_dismiss: :dismissed},
        children: [%{type: :text, props: %{text: "Modal"}, children: []}]
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-modal"
    end

    test "renders pressable container" do
      ui_tree = %{
        type: :pressable,
        props: %{on_press: :pressed},
        children: [%{type: :text, props: %{text: "Press me"}, children: []}]
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-pressable"
    end

    test "renders safe_area container" do
      ui_tree = %{
        type: :safe_area,
        props: %{},
        children: [%{type: :text, props: %{text: "Safe"}, children: []}]
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-safe_area"
    end
  end

  describe "media components" do
    test "renders image component" do
      ui_tree = %{
        type: :image,
        props: %{src: "https://example.com/photo.jpg", width: 200, height: 150},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-image"
    end

    test "renders video component" do
      ui_tree = %{
        type: :video,
        props: %{src: "https://example.com/video.mp4", autoplay: true},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-video"
    end

    test "renders activity_indicator" do
      ui_tree = %{type: :activity_indicator, props: %{size: :large}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-activity-indicator"
    end

    test "renders progress_bar with value" do
      ui_tree = %{type: :progress_bar, props: %{value: 75}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-progress-bar"
      assert html =~ "75%"
    end

    test "renders webview" do
      ui_tree = %{
        type: :webview,
        props: %{src: "https://elixir-lang.org", width: 400, height: 600},
        children: []
      }

      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-webview"
    end

    test "renders camera_preview" do
      ui_tree = %{type: :camera_preview, props: %{facing: :front}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-camera-preview"
    end

    test "renders native_view" do
      ui_tree = %{type: :native_view, props: %{module: "MyApp.Chart"}, children: []}
      html = Dala.Preview.preview(ui_tree)
      assert html =~ "dala-native-view"
    end
  end
end
