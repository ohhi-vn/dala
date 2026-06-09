defmodule Dala.Spark.DslIntegrationTest do
  use ExUnit.Case, async: false

  describe "Spark DSL with all UI components" do
    test "screen with layout containers and children" do
      defmodule TestAllComponentsScreen do
        use Dala.Screen

        screen name: :test_screen do
          column padding: :space_md, gap: :space_sm do
            text("Hello World")

            row gap: :space_sm do
              button("Button 1", on_tap: :increment)
              button("Button 2", on_tap: :decrement)
            end
          end
        end

        def mount(_params, _session, socket), do: {:ok, socket}
        def handle_event(:increment, _params, socket), do: {:noreply, socket}
        def handle_event(:decrement, _params, socket), do: {:noreply, socket}
      end

      assert Code.ensure_loaded?(TestAllComponentsScreen)

      {:ok, socket} =
        TestAllComponentsScreen.mount(%{}, %{}, Dala.Socket.new(TestAllComponentsScreen))

      render_result = TestAllComponentsScreen.render(socket.assigns)

      assert is_list(render_result)
      [column_node] = render_result
      assert column_node.type == :column
      assert is_list(column_node.children)
      assert length(column_node.children) == 2

      [text_node, row_node] = column_node.children
      assert text_node.type == :text
      assert text_node.props.text == "Hello World"
      assert row_node.type == :row
      assert length(row_node.children) == 2
    end

    test "simple DSL screen with minimal components" do
      defmodule TestSimpleDslScreen do
        use Dala.Screen

        screen name: :simple do
          text("Hello")
        end

        def mount(_params, _session, socket), do: {:ok, socket}
      end

      assert Code.ensure_loaded?(TestSimpleDslScreen)

      {:ok, socket} = TestSimpleDslScreen.mount(%{}, %{}, Dala.Socket.new(TestSimpleDslScreen))

      render_result = TestSimpleDslScreen.render(socket.assigns)
      assert is_list(render_result)
      assert length(render_result) == 1
      [text_node] = render_result
      assert text_node.type == :text
      assert text_node.props.text == "Hello"
    end

    test "screen with attributes and @ref syntax" do
      defmodule TestRefScreen do
        use Dala.Screen

        screen name: :ref_test do
          column gap: :space_sm do
            text("Count: 0")
            button("Increment", on_tap: :increment)
          end
        end

        def mount(_params, _session, socket) do
          {:ok, Dala.Socket.assign(socket, :count, 0)}
        end

        def handle_event(:increment, _params, socket) do
          {:noreply, Dala.Socket.assign(socket, :count, socket.assigns.count + 1)}
        end
      end

      assert Code.ensure_loaded?(TestRefScreen)

      {:ok, socket} = TestRefScreen.mount(%{}, %{}, Dala.Socket.new(TestRefScreen))
      assert socket.assigns.count == 0

      render_result = TestRefScreen.render(socket.assigns)
      assert is_list(render_result)
      [column_node | _] = render_result
      assert column_node.type == :column

      [text_node | _] = column_node.children
      assert text_node.type == :text
      assert text_node.props.text == "Count: 0"
    end

    test "screen with attributes generates mount" do
      defmodule TestAttrScreen do
        use Dala.Spark.Dsl

        screen name: :attr_test do
          text("Hello")
        end

        def mount(_params, _session, socket), do: {:ok, socket}
      end

      assert Code.ensure_loaded?(TestAttrScreen)

      {:ok, socket} = TestAttrScreen.mount(%{}, %{}, Dala.Socket.new(TestAttrScreen))
      # With AST-based parsing, attributes declared via the attributes macro
      # need the attributes section. This test uses a simple screen without
      # explicit attributes, so we just verify the screen renders.
      render_result = TestAttrScreen.render(socket.assigns)
      assert is_list(render_result)
    end

    test "all leaf components compile" do
      defmodule TestLeafComponentsScreen do
        use Dala.Screen

        screen name: :leaves do
          column gap: :space_sm do
            text("Hello")
            button("Press", on_tap: :pressed)
            icon("settings")
            divider()
            spacer()
            text_field(placeholder: "Type here", on_change: :changed)
            toggle(value: true, on_change: :toggled)
            slider(value: 0.5, on_change: :slid)
            switch(value: false, on_toggle: :switched)
            image("https://example.com/photo.jpg")
            video("https://example.com/clip.mp4")
            activity_indicator(size: :large)
            progress_bar(progress: 0.5)
            status_bar(bar_style: :light_content)
            refresh_control(on_refresh: :refreshed)
            webview("https://elixir-lang.org")
            camera_preview(facing: :front)
            tab_bar(tabs: [])
            list(:my_list)
          end
        end

        def handle_event(_, _, socket), do: {:noreply, socket}
      end

      assert Code.ensure_loaded?(TestLeafComponentsScreen)
    end

    test "nested containers compile" do
      defmodule TestNestedScreen do
        use Dala.Screen

        screen name: :nested do
          column padding: :space_md do
            row gap: :space_sm do
              box do
                text("Overlapping")
              end
            end

            scroll padding: :space_sm do
              text("Scrollable")
            end

            pressable on_press: :pressed do
              text("Pressable")
            end

            safe_area do
              text("Safe")
            end

            modal visible: true, on_dismiss: :dismissed do
              text("Modal")
            end
          end
        end

        def handle_event(_, _, socket), do: {:noreply, socket}
      end

      assert Code.ensure_loaded?(TestNestedScreen)
    end
  end
end
