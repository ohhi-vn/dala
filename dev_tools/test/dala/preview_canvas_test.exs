defmodule Dala.Designer.CanvasTest do
  @moduledoc """
  Tests for the Canvas LiveView's internal tree manipulation,
  prop parsing, and preview rendering logic.

  These exercise the private functions of Dala.Designer.Canvas
  via the public-facing render pipeline and handle_event callbacks.
  """
  use ExUnit.Case, async: true

  # ── Helpers to call private functions ───────────────────────────────────────

  defp call_private(fun, args), do: Dala.Designer.Canvas.call_private(fun, args)

  defp pipe_call(private_fun, pipe_arg, extra_args) do
    Dala.Designer.Canvas.call_private(private_fun, [pipe_arg | extra_args])
  end

  describe "empty_root/0" do
    test "creates a column root with default props" do
      root = call_private(:empty_root, [])
      assert root.type == :column
      assert root.props == %{padding: :md, gap: :sm}
      assert root.children == []
      assert root.id == "node_0"
    end
  end

  describe "make_node/2" do
    test "creates a leaf node with defaults" do
      node = call_private(:make_node, [:text, 42])
      assert node.type == :text
      assert node.id == "node_42"
      assert node.props.text == "Text"
      assert node.children == []
    end

    test "creates a container node with empty children" do
      node = call_private(:make_node, [:column, 7])
      assert node.type == :column
      assert node.id == "node_7"
      assert node.children == []
      assert node.props.padding == :sm
    end

    test "creates a button node" do
      node = call_private(:make_node, [:button, 1])
      assert node.type == :button
      assert node.props.text == "Button"
    end

    test "creates a card node" do
      node = call_private(:make_node, [:card, 2])
      assert node.type == :card
      assert node.props.variant == :elevated
      assert node.props.elevation == 1.0
    end

    test "creates a chip node" do
      node = call_private(:make_node, [:chip, 3])
      assert node.type == :chip
      assert node.props.label == "Chip"
      assert node.props.variant == :filter
    end

    test "creates a fab node" do
      node = call_private(:make_node, [:fab, 4])
      assert node.type == :fab
      assert node.props.icon == :add
    end

    test "creates a search_bar node" do
      node = call_private(:make_node, [:search_bar, 5])
      assert node.type == :search_bar
      assert node.props.placeholder == "Search..."
    end
  end

  describe "add_node_to_tree/3" do
    test "adds a child to root" do
      root = call_private(:empty_root, [])
      child = call_private(:make_node, [:text, 1])
      updated = call_private(:add_node_to_tree, [root, root.id, child])
      assert length(updated.children) == 1
      assert hd(updated.children).type == :text
    end

    test "adds multiple children in order" do
      root = call_private(:empty_root, [])
      t1 = call_private(:make_node, [:text, 1])
      t2 = call_private(:make_node, [:button, 2])
      updated = pipe_call(:add_node_to_tree, root, [root.id, t1]) |> then(&pipe_call(:add_node_to_tree, &1, [root.id, t2]))
      assert length(updated.children) == 2
      assert Enum.at(updated.children, 0).type == :text
      assert Enum.at(updated.children, 1).type == :button
    end

    test "adds a child to a nested container" do
      root = call_private(:empty_root, [])
      row = call_private(:make_node, [:row, 1])
      root = call_private(:add_node_to_tree, [root, root.id, row])
      text = call_private(:make_node, [:text, 2])
      updated = call_private(:add_node_to_tree, [root, row.id, text])
      [first_child] = updated.children
      assert first_child.type == :row
      assert length(first_child.children) == 1
      assert hd(first_child.children).type == :text
    end

    test "does not add to a leaf node target" do
      root = call_private(:empty_root, [])
      text = call_private(:make_node, [:text, 1])
      root = call_private(:add_node_to_tree, [root, root.id, text])
      button = call_private(:make_node, [:button, 2])
      # Adding to a leaf (text) should not modify text's children
      updated = call_private(:add_node_to_tree, [root, text.id, button])
      [text_child] = updated.children
      assert text_child.children == []
    end
  end

  describe "remove_node_from_tree/2" do
    test "removes a direct child" do
      root = call_private(:empty_root, [])
      t1 = call_private(:make_node, [:text, 1])
      t2 = call_private(:make_node, [:button, 2])
      root = pipe_call(:add_node_to_tree, root, [root.id, t1]) |> then(&pipe_call(:add_node_to_tree, &1, [root.id, t2]))
      updated = call_private(:remove_node_from_tree, [root, t1.id])
      assert length(updated.children) == 1
      assert hd(updated.children).type == :button
    end

    test "removes a deeply nested child" do
      root = call_private(:empty_root, [])
      row = call_private(:make_node, [:row, 1])
      text = call_private(:make_node, [:text, 2])
      root = call_private(:add_node_to_tree, [root, root.id, row])
      root = call_private(:add_node_to_tree, [root, row.id, text])
      updated = call_private(:remove_node_from_tree, [root, text.id])
      [row_child] = updated.children
      assert row_child.children == []
    end

    test "returns unchanged tree when node not found" do
      root = call_private(:empty_root, [])
      updated = call_private(:remove_node_from_tree, [root, "nonexistent"])
      assert updated.children == []
    end
  end

  describe "update_node_in_tree/3" do
    test "updates props on a direct child" do
      root = call_private(:empty_root, [])
      text = call_private(:make_node, [:text, 1])
      root = call_private(:add_node_to_tree, [root, root.id, text])
      updated = call_private(:update_node_in_tree, [root, text.id, fn n -> %{n | props: Map.put(n.props, :text, "Updated")} end])
      [child] = updated.children
      assert child.props.text == "Updated"
    end

    test "updates props on root itself" do
      root = call_private(:empty_root, [])
      updated = call_private(:update_node_in_tree, [root, root.id, fn n -> %{n | props: %{n.props | padding: :lg}} end])
      assert updated.props.padding == :lg
    end

    test "updates deeply nested node" do
      root = call_private(:empty_root, [])
      col = call_private(:make_node, [:column, 1])
      text = call_private(:make_node, [:text, 2])
      root = call_private(:add_node_to_tree, [root, root.id, col])
      root = call_private(:add_node_to_tree, [root, col.id, text])
      updated = call_private(:update_node_in_tree, [root, text.id, fn n -> %{n | props: %{n.props | text: "Deep"}} end])
      [col_child] = updated.children
      [text_child] = col_child.children
      assert text_child.props.text == "Deep"
    end
  end

  describe "find_node/2" do
    test "finds root by id" do
      root = call_private(:empty_root, [])
      assert call_private(:find_node, [root, root.id]) == root
    end

    test "finds a direct child" do
      root = call_private(:empty_root, [])
      text = call_private(:make_node, [:text, 1])
      root = call_private(:add_node_to_tree, [root, root.id, text])
      found = call_private(:find_node, [root, text.id])
      assert found != nil
      assert found.type == :text
    end

    test "finds a deeply nested node" do
      root = call_private(:empty_root, [])
      col = call_private(:make_node, [:column, 1])
      row = call_private(:make_node, [:row, 2])
      text = call_private(:make_node, [:text, 3])
      root = pipe_call(:add_node_to_tree, root, [root.id, col]) |> then(&pipe_call(:add_node_to_tree, &1, [col.id, row]))
      root = call_private(:add_node_to_tree, [root, row.id, text])
      found = call_private(:find_node, [root, text.id])
      assert found != nil
      assert found.type == :text
    end

    test "returns nil for nonexistent id" do
      root = call_private(:empty_root, [])
      assert call_private(:find_node, [root, "nope"]) == nil
    end
  end

  describe "strip_ids/1" do
    test "removes id from root" do
      root = call_private(:empty_root, [])
      stripped = call_private(:strip_ids, [root])
      refute Map.has_key?(stripped, :id)
    end

    test "recursively removes ids from all children" do
      root = call_private(:empty_root, [])
      t1 = call_private(:make_node, [:text, 1])
      t2 = call_private(:make_node, [:button, 2])
      root = pipe_call(:add_node_to_tree, root, [root.id, t1]) |> then(&pipe_call(:add_node_to_tree, &1, [root.id, t2]))
      stripped = call_private(:strip_ids, [root])
      refute Map.has_key?(stripped, :id)
      Enum.each(stripped.children, fn child ->
        refute Map.has_key?(child, :id)
      end)
    end

    test "preserves type, props, and children structure" do
      root = call_private(:empty_root, [])
      text = call_private(:make_node, [:text, 1])
      root = call_private(:add_node_to_tree, [root, root.id, text])
      stripped = call_private(:strip_ids, [root])
      assert stripped.type == :column
      assert stripped.props == %{padding: :md, gap: :sm}
      assert length(stripped.children) == 1
      assert hd(stripped.children).type == :text
    end
  end

  describe "default_props/1" do
    test "text has default text prop" do
      assert call_private(:default_props, [:text]) == %{text: "Text"}
    end

    test "button has default text prop" do
      assert call_private(:default_props, [:button]) == %{text: "Button"}
    end

    test "icon has default name" do
      assert call_private(:default_props, [:icon]) == %{name: :star}
    end

    test "text_field has placeholder" do
      assert call_private(:default_props, [:text_field]) == %{placeholder: "Type here..."}
    end

    test "slider has default value" do
      assert call_private(:default_props, [:slider]) == %{value: 50}
    end

    test "column has padding and gap" do
      props = call_private(:default_props, [:column])
      assert props.padding == :sm
      assert props.gap == :sm
    end

    test "unknown type returns empty map" do
      assert call_private(:default_props, [:nonexistent]) == %{}
    end

    test "card has elevation defaults" do
      props = call_private(:default_props, [:card])
      assert props.variant == :elevated
      assert props.elevation == 1.0
      assert props.corner_radius == 12
    end

    test "chip has label and variant" do
      props = call_private(:default_props, [:chip])
      assert props.label == "Chip"
      assert props.variant == :filter
    end

    test "fab has icon" do
      assert call_private(:default_props, [:fab]) == %{icon: :add}
    end

    test "search_bar has placeholder" do
      assert call_private(:default_props, [:search_bar]) == %{placeholder: "Search..."}
    end

    test "app_bar has title" do
      assert call_private(:default_props, [:app_bar]) == %{title: "My App"}
    end

    test "checkbox has label and value" do
      props = call_private(:default_props, [:checkbox])
      assert props.label == "Checkbox"
      assert props.value == false
    end

    test "radio has label and selected" do
      props = call_private(:default_props, [:radio])
      assert props.label == "Radio"
      assert props.selected == false
    end

    test "snackbar has message and visible" do
      props = call_private(:default_props, [:snackbar])
      assert props.message == "Notification"
      assert props.visible == false
    end
  end

  describe "parse_prop_value/2 (via update_prop pipeline)" do
    test "parses string values" do
      assert call_private(:parse_prop_value, ["hello", nil]) == "hello"
    end

    test "parses integer values" do
      assert call_private(:parse_prop_value, ["42", nil]) == 42
    end

    test "parses float values" do
      assert call_private(:parse_prop_value, ["3.14", nil]) == 3.14
    end

    test "parses boolean true" do
      assert call_private(:parse_prop_value, ["true", nil]) == true
    end

    test "parses boolean false" do
      assert call_private(:parse_prop_value, ["false", nil]) == false
    end

    test "parses atom values" do
      assert call_private(:parse_prop_value, ["primary", {:text_color, :atom, nil}]) == :primary
    end

    test "parses atom with colon prefix" do
      assert call_private(:parse_prop_value, [":primary", {:text_color, :atom, nil}]) == :primary
    end

    test "returns nil for empty atom string" do
      assert call_private(:parse_prop_value, ["", {:text_color, :atom, nil}]) == nil
    end

    test "parses integer with spec" do
      assert call_private(:parse_prop_value, ["100", {:value, :integer, 0}]) == 100
    end

    test "returns nil for invalid integer" do
      assert call_private(:parse_prop_value, ["abc", {:value, :integer, 0}]) == nil
    end

    test "parses float with spec" do
      assert call_private(:parse_prop_value, ["2.5", {:elevation, :float, 1.0}]) == 2.5
    end

    test "returns nil for invalid float" do
      assert call_private(:parse_prop_value, ["abc", {:elevation, :float, 1.0}]) == nil
    end

    test "parses boolean true with spec" do
      assert call_private(:parse_prop_value, ["true", {:disabled, :boolean, false}]) == true
    end

    test "parses boolean false with spec" do
      assert call_private(:parse_prop_value, ["false", {:disabled, :boolean, false}]) == false
    end

    test "parses event handler as string" do
      assert call_private(:parse_prop_value, ["my_handler", {:on_tap, :event, nil}]) == "my_handler"
    end

    test "parses string with spec" do
      assert call_private(:parse_prop_value, ["hello", {:text, :string, ""}]) == "hello"
    end
  end

  describe "container_type?/1" do
    test "column is a container" do
      assert call_private(:container_type?, [:column]) == true
    end

    test "row is a container" do
      assert call_private(:container_type?, [:row]) == true
    end

    test "box is a container" do
      assert call_private(:container_type?, [:box]) == true
    end

    test "card is a container" do
      assert call_private(:container_type?, [:card]) == true
    end

    test "text is not a container" do
      assert call_private(:container_type?, [:text]) == false
    end

    test "button is not a container" do
      assert call_private(:container_type?, [:button]) == false
    end
  end

  describe "has_children?/1" do
    test "node with children has children" do
      node = %{children: [%{type: :text}]}
      assert call_private(:has_children?, [node]) == true
    end

    test "node without children key" do
      node = %{type: :text}
      assert call_private(:has_children?, [node]) == false
    end

    test "node with empty children" do
      node = %{children: []}
      assert call_private(:has_children?, [node]) == false
    end
  end

  describe "format_type/1" do
    test "formats text_field as TextField" do
      assert call_private(:format_type, [:text_field]) == "TextField"
    end

    test "formats activity_indicator" do
      assert call_private(:format_type, [:activity_indicator]) == "ActivityIndicator"
    end

    test "formats progress_bar" do
      assert call_private(:format_type, [:progress_bar]) == "ProgressBar"
    end

    test "formats simple atoms" do
      assert call_private(:format_type, [:text]) == "Text"
      assert call_private(:format_type, [:button]) == "Button"
      assert call_private(:format_type, [:column]) == "Column"
    end

    test "formats multi-word atoms" do
      assert call_private(:format_type, [:icon_button]) == "IconButton"
      assert call_private(:format_type, [:search_bar]) == "SearchBar"
    end
  end

  describe "truncate/2" do
    test "truncates long strings" do
      assert call_private(:truncate, ["Hello World This Is Long", 10]) == "Hello Worl…"
    end

    test "does not truncate short strings" do
      assert call_private(:truncate, ["Hi", 10]) == "Hi"
    end

    test "returns empty for non-string" do
      assert call_private(:truncate, [123, 10]) == ""
    end
  end

  describe "v0.8 new component defaults and canvas ops" do
    test "skeleton has default props" do
      props = call_private(:default_props, [:skeleton])
      assert is_map(props)
    end

    test "empty_state has default props" do
      props = call_private(:default_props, [:empty_state])
      assert is_map(props)
    end

    test "avatar has default props" do
      props = call_private(:default_props, [:avatar])
      assert is_map(props)
    end

    test "stepper has default props" do
      props = call_private(:default_props, [:stepper])
      assert is_map(props)
    end

    test "grid has default props" do
      props = call_private(:default_props, [:grid])
      assert is_map(props)
    end

    test "grid is a container type" do
      assert call_private(:container_type?, [:grid]) == true
    end

    test "skeleton is not a container type" do
      assert call_private(:container_type?, [:skeleton]) == false
    end

    test "empty_state is not a container type" do
      assert call_private(:container_type?, [:empty_state]) == false
    end

    test "avatar is not a container type" do
      assert call_private(:container_type?, [:avatar]) == false
    end

    test "stepper is not a container type" do
      assert call_private(:container_type?, [:stepper]) == false
    end

    test "make_node creates skeleton with counter" do
      node = call_private(:make_node, [:skeleton, 99])
      assert node.type == :skeleton
      assert node.id == "node_99"
    end

    test "make_node creates grid with counter" do
      node = call_private(:make_node, [:grid, 55])
      assert node.type == :grid
      assert node.id == "node_55"
      assert node.children == []
    end

    test "add skeleton to tree and find it" do
      root = call_private(:empty_root, [])
      sk = call_private(:make_node, [:skeleton, 10])
      root = call_private(:add_node_to_tree, [root, root.id, sk])
      found = call_private(:find_node, [root, sk.id])
      assert found != nil
      assert found.type == :skeleton
    end

    test "add grid with children to tree" do
      root = call_private(:empty_root, [])
      grid = call_private(:make_node, [:grid, 20])
      root = call_private(:add_node_to_tree, [root, root.id, grid])
      text = call_private(:make_node, [:text, 21])
      root = call_private(:add_node_to_tree, [root, grid.id, text])
      [grid_child] = root.children
      assert grid_child.type == :grid
      assert length(grid_child.children) == 1
      assert hd(grid_child.children).type == :text
    end

    test "remove skeleton from tree" do
      root = call_private(:empty_root, [])
      sk = call_private(:make_node, [:skeleton, 30])
      root = call_private(:add_node_to_tree, [root, root.id, sk])
      assert length(root.children) == 1
      root = call_private(:remove_node_from_tree, [root, sk.id])
      assert root.children == []
    end

    test "update avatar props in tree" do
      root = call_private(:empty_root, [])
      av = call_private(:make_node, [:avatar, 40])
      root = call_private(:add_node_to_tree, [root, root.id, av])
      updated = call_private(:update_node_in_tree, [root, av.id, fn n -> %{n | props: Map.put(n.props, :size, 64)} end])
      [child] = updated.children
      assert child.props.size == 64
    end

    test "format_type formats new components" do
      assert call_private(:format_type, [:skeleton]) == "Skeleton"
      assert call_private(:format_type, [:empty_state]) == "EmptyState"
      assert call_private(:format_type, [:avatar]) == "Avatar"
      assert call_private(:format_type, [:stepper]) == "Stepper"
      assert call_private(:format_type, [:grid]) == "Grid"
    end
  end
end
