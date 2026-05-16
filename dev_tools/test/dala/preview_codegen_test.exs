defmodule Dala.Preview.CodegenEdgeCaseTest do
  @moduledoc """
  Edge-case and comprehensive tests for Dala.Preview.Codegen.
  """
  use ExUnit.Case, async: true

  describe "generate_dsl/3 edge cases" do
    test "generates code for a single leaf node" do
      tree = %{type: :text, props: %{text: "Hello"}, children: []}
      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", tree)
      assert code =~ "defmodule MyApp.Screen do"
      assert code =~ ~s(text "Hello")
    end

    test "generates code for deeply nested tree" do
      tree = %{
        type: :column,
        props: %{},
        children: [
          %{
            type: :row,
            props: %{},
            children: [
              %{
                type: :box,
                props: %{},
                children: [
                  %{type: :text, props: %{text: "Deep"}, children: []}
                ]
              }
            ]
          }
        ]
      }

      code = Dala.Preview.Codegen.generate_dsl("MyApp.DeepScreen", tree)
      assert code =~ "column"
      assert code =~ "row"
      assert code =~ "box"
      assert code =~ ~s(text "Deep")
    end

    test "handles empty children list" do
      tree = %{type: :column, props: %{}, children: []}
      code = Dala.Preview.Codegen.generate_dsl("MyApp.Empty", tree)
      assert code =~ "defmodule MyApp.Empty do"
      assert code =~ "column"
    end

    test "handles nil props gracefully" do
      tree = %{type: :text, props: nil, children: []}
      # normalize_tree should handle this
      code = Dala.Preview.Codegen.generate_dsl("MyApp.NilProps", tree)
      assert code =~ "defmodule MyApp.NilProps do"
    end

    test "handles string keys in tree (JSON-style)" do
      tree = %{
        "type" => :column,
        "props" => %{},
        "children" => [
          %{"type" => :text, "props" => %{"text" => "JSON"}, "children" => []}
        ]
      }

      code = Dala.Preview.Codegen.generate_dsl("MyApp.JsonTree", tree)
      assert code =~ "defmodule MyApp.JsonTree do"
      assert code =~ ~s(text "JSON")
    end

    test "generates handler for on_long_press" do
      tree = %{
        type: :button,
        props: %{text: "Press", on_long_press: :long_press_handler},
        children: []
      }

      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", tree)
      assert code =~ "handle_event(:long_press_handler"
    end

    test "generates handler for on_change" do
      tree = %{
        type: :text_field,
        props: %{placeholder: "Name", on_change: :name_changed},
        children: []
      }

      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", tree)
      assert code =~ "handle_event(:name_changed"
    end

    test "generates handler for on_focus and on_blur" do
      tree = %{
        type: :text_field,
        props: %{on_focus: :focused, on_blur: :blurred},
        children: []
      }

      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", tree)
      assert code =~ "handle_event(:focused"
      assert code =~ "handle_event(:blurred"
    end

    test "generates handler for on_submit" do
      tree = %{
        type: :text_field,
        props: %{on_submit: :submitted},
        children: []
      }

      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", tree)
      assert code =~ "handle_event(:submitted"
    end

    test "generates handler for on_refresh" do
      tree = %{
        type: :refresh_control,
        props: %{on_refresh: :reload},
        children: []
      }

      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", tree)
      assert code =~ "handle_event(:reload"
    end

    test "generates handler for on_dismiss" do
      tree = %{
        type: :modal,
        props: %{on_dismiss: :dismissed},
        children: []
      }

      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", tree)
      assert code =~ "handle_event(:dismissed"
    end

    test "generates handler for on_tab_select" do
      tree = %{
        type: :tab_bar,
        props: %{on_tab_select: :tab_changed},
        children: []
      }

      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", tree)
      assert code =~ "handle_event(:tab_changed"
    end

    test "generates handler for on_end_reached" do
      tree = %{
        type: :list,
        props: %{on_end_reached: :load_more},
        children: []
      }

      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", tree)
      assert code =~ "handle_event(:load_more"
    end

    test "generates handler for on_scroll" do
      tree = %{
        type: :scroll,
        props: %{on_scroll: :scrolled},
        children: []
      }

      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", tree)
      assert code =~ "handle_event(:scrolled"
    end

    test "generates handler for on_toggle" do
      tree = %{
        type: :switch,
        props: %{on_toggle: :toggled},
        children: []
      }

      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", tree)
      assert code =~ "handle_event(:toggled"
    end

    test "generates handler for on_press" do
      tree = %{
        type: :pressable,
        props: %{on_press: :pressed},
        children: []
      }

      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", tree)
      assert code =~ "handle_event(:pressed"
    end

    test "generates handler for on_double_tap" do
      tree = %{
        type: :box,
        props: %{on_double_tap: :double_tapped},
        children: []
      }

      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", tree)
      assert code =~ "handle_event(:double_tapped"
    end

    test "generates multiple handlers in sorted order" do
      tree = %{
        type: :column,
        props: %{},
        children: [
          %{type: :button, props: %{on_tap: :zebra}, children: []},
          %{type: :button, props: %{on_tap: :alpha}, children: []},
          %{type: :button, props: %{on_tap: :middle}, children: []}
        ]
      }

      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", tree)
      alpha_pos = :binary.match(code, "handle_event(:alpha") |> elem(0)
      middle_pos = :binary.match(code, "handle_event(:middle") |> elem(0)
      zebra_pos = :binary.match(code, "handle_event(:zebra") |> elem(0)
      assert alpha_pos < middle_pos
      assert middle_pos < zebra_pos
    end

    test "handles module name as atom" do
      tree = %{type: :text, props: %{text: "Hi"}, children: []}
      code = Dala.Preview.Codegen.generate_dsl(MyApp.AtomName, tree)
      assert code =~ "defmodule Elixir.MyApp.AtomName do"
    end

    test "handles module name with nested namespace" do
      tree = %{type: :text, props: %{text: "Hi"}, children: []}
      code = Dala.Preview.Codegen.generate_dsl("MyApp.Admin.Dashboard.Header", tree)
      assert code =~ "defmodule MyApp.Admin.Dashboard.Header do"
      assert code =~ "screen name: :header"
    end

    test "renders boolean true props" do
      tree = %{
        type: :button,
        props: %{text: "Go", fill_width: true, disabled: false},
        children: []
      }

      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", tree)
      assert code =~ "fill_width: true"
      refute code =~ "disabled: false"
    end

    test "renders nil props as omitted" do
      tree = %{
        type: :text,
        props: %{text: "Hello", text_color: nil, text_size: nil},
        children: []
      }

      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", tree)
      refute code =~ "text_color"
      refute code =~ "text_size"
    end

    test "renders integer props" do
      tree = %{
        type: :slider,
        props: %{value: 75, on_change: :changed},
        children: []
      }

      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", tree)
      assert code =~ "value: 75"
    end

    test "renders atom props with colon prefix" do
      tree = %{
        type: :text,
        props: %{text: "Hello", text_color: :primary, text_size: :xl},
        children: []
      }

      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", tree)
      assert code =~ "text_color: :primary"
      assert code =~ "text_size: :xl"
    end

    test "renders string props with quotes" do
      tree = %{
        type: :text_field,
        props: %{placeholder: "Enter your name..."},
        children: []
      }

      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", tree)
      assert code =~ ~s(placeholder: "Enter your name...")
    end

    test "renders event handler props as atoms" do
      tree = %{
        type: :button,
        props: %{text: "Go", on_tap: :go_pressed},
        children: []
      }

      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", tree)
      assert code =~ "on_tap: :go_pressed"
    end

    test "renders {self(), :tag} as atom" do
      tree = %{
        type: :button,
        props: %{text: "Go", on_tap: {self(), :submit}},
        children: []
      }

      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", tree)
      assert code =~ "on_tap: :submit"
    end

    test "generates attributes block when provided" do
      tree = %{type: :text, props: %{text: "Hi"}, children: []}

      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", tree,
        attributes: [
          {:count, :integer, 0},
          {:name, :string, nil},
          {:active, :boolean, true}
        ]
      )

      assert code =~ "attributes do"
      assert code =~ "attribute :count, :integer, default: 0"
      assert code =~ "attribute :name, :string"
      assert code =~ "attribute :active, :boolean, default: true"
    end

    test "omits attributes block when empty" do
      tree = %{type: :text, props: %{text: "Hi"}, children: []}
      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", tree)
      refute code =~ "attributes do"
    end

    test "generates handler stubs with correct indentation" do
      tree = %{
        type: :button,
        props: %{text: "Go", on_tap: :go},
        children: []
      }

      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", tree)
      assert code =~ "def handle_event(:go, _params, socket) do"
      assert code =~ "  {:noreply, socket}"
    end

    test "handles list of trees as input" do
      trees = [
        %{type: :text, props: %{text: "First"}, children: []},
        %{type: :text, props: %{text: "Second"}, children: []}
      ]

      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", trees)
      assert code =~ ~s(text "First")
      assert code =~ ~s(text "Second")
    end

    test "single-element list is unwrapped" do
      trees = [%{type: :text, props: %{text: "Only"}, children: []}]
      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", trees)
      assert code =~ ~s(text "Only")
    end

    test "screen name is derived from last module segment" do
      tree = %{type: :text, props: %{text: "Hi"}, children: []}

      code1 = Dala.Preview.Codegen.generate_dsl("MyApp.HomeScreen", tree)
      assert code1 =~ "screen name: :home_screen"

      code2 = Dala.Preview.Codegen.generate_dsl("MyApp.Settings.DarkMode", tree)
      assert code2 =~ "screen name: :dark_mode"
    end
  end

  describe "extract_handlers/1 edge cases" do
    test "returns empty list for tree with no handlers" do
      tree = %{
        type: :column,
        props: %{},
        children: [
          %{type: :text, props: %{text: "No handlers"}, children: []}
        ]
      }

      assert Dala.Preview.Codegen.extract_handlers(tree) == []
    end

    test "extracts handlers from deeply nested tree" do
      tree = %{
        type: :column,
        props: %{},
        children: [
          %{
            type: :row,
            props: %{},
            children: [
              %{
                type: :box,
                props: %{},
                children: [
                  %{type: :button, props: %{on_tap: :deep_tap}, children: []}
                ]
              }
            ]
          }
        ]
      }

      handlers = Dala.Preview.Codegen.extract_handlers(tree)
      assert :deep_tap in handlers
    end

    test "extracts handlers from all event prop types" do
      tree = %{
        type: :column,
        props: %{},
        children: [
          %{type: :button, props: %{on_tap: :tapped, on_long_press: :long_pressed, on_double_tap: :double_tapped}, children: []},
          %{type: :text_field, props: %{on_change: :changed, on_focus: :focused, on_blur: :blurred, on_submit: :submitted}, children: []},
          %{type: :slider, props: %{on_change: :slid}, children: []},
          %{type: :scroll, props: %{on_scroll: :scrolled}, children: []},
          %{type: :list, props: %{on_end_reached: :more}, children: []},
          %{type: :refresh_control, props: %{on_refresh: :refreshed}, children: []},
          %{type: :modal, props: %{on_dismiss: :dismissed}, children: []},
          %{type: :tab_bar, props: %{on_tab_select: :tabbed}, children: []},
          %{type: :switch, props: %{on_toggle: :toggled}, children: []},
          %{type: :pressable, props: %{on_press: :pressed}, children: []}
        ]
      }

      handlers = Dala.Preview.Codegen.extract_handlers(tree)
      assert length(handlers) == 15
      assert :tapped in handlers
      assert :long_pressed in handlers
      assert :double_tapped in handlers
      assert :changed in handlers
      assert :focused in handlers
      assert :blurred in handlers
      assert :submitted in handlers
      assert :slid in handlers
      assert :scrolled in handlers
      assert :more in handlers
      assert :refreshed in handlers
      assert :dismissed in handlers
      assert :tabbed in handlers
      assert :toggled in handlers
      assert :pressed in handlers
    end

    test "handles nil children gracefully" do
      tree = %{type: :text, props: %{text: "Hi"}, children: nil}
      # collect_handlers should handle nil children
      handlers = Dala.Preview.Codegen.extract_handlers(tree)
      assert handlers == []
    end

    test "handles node without children key" do
      tree = %{type: :text, props: %{text: "Hi"}}
      handlers = Dala.Preview.Codegen.extract_handlers(tree)
      assert handlers == []
    end

    test "extracts bare atom handler" do
      tree = %{type: :button, props: %{on_tap: :my_handler}, children: []}
      assert :my_handler in Dala.Preview.Codegen.extract_handlers(tree)
    end

    test "extracts tuple handler with self()" do
      tree = %{type: :button, props: %{on_tap: {self(), :submit}}, children: []}
      assert :submit in Dala.Preview.Codegen.extract_handlers(tree)
    end

    test "sorts handlers alphabetically" do
      tree = %{
        type: :column,
        props: %{},
        children: [
          %{type: :button, props: %{on_tap: :zebra}, children: []},
          %{type: :button, props: %{on_tap: :alpha}, children: []},
          %{type: :button, props: %{on_tap: :mango}, children: []}
        ]
      }

      handlers = Dala.Preview.Codegen.extract_handlers(tree)
      assert handlers == [:alpha, :mango, :zebra]
    end
  end

  describe "normalize_tree/1" do
    test "normalizes node missing props" do
      tree = %{type: :text}
      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", tree)
      assert code =~ "defmodule MyApp.Screen do"
    end

    test "normalizes node missing children" do
      tree = %{type: :column, props: %{}}
      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", tree)
      assert code =~ "defmodule MyApp.Screen do"
    end

    test "normalizes list of nodes" do
      trees = [
        %{type: :text, props: %{text: "A"}},
        %{type: :text, props: %{text: "B"}}
      ]

      code = Dala.Preview.Codegen.generate_dsl("MyApp.Screen", trees)
      assert code =~ ~s(text "A")
      assert code =~ ~s(text "B")
    end
  end
end
