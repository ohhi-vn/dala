defmodule Dala.Preview.Canvas do
  @moduledoc """
  Interactive drag-and-drop UI design canvas for Dala.

  A Phoenix LiveView that provides a visual design tool with:
  - Component palette (left sidebar)
  - Design canvas with live preview (center)
  - Property editor (right sidebar)
  - Code preview panel (bottom, collapsible)

  Uses the Dala UI tree map format internally with unique IDs for tracking.
  IDs are stripped during code generation.
  """

  use Phoenix.LiveView
  import Phoenix.HTML
  alias Dala.Preview.Codegen

  @container_types [:column, :row, :box, :scroll, :modal, :pressable, :safe_area]

  @layout_palette [
    {:column, "Column", "Vertical layout container"},
    {:row, "Row", "Horizontal layout container"},
    {:box, "Box", "Generic container"},
    {:scroll, "Scroll", "Scrollable container"},
    {:modal, "Modal", "Modal overlay"},
    {:pressable, "Pressable", "Tappable container"},
    {:safe_area, "SafeArea", "Safe area inset container"}
  ]

  @leaf_palette [
    {:text, "Text", "Text label"},
    {:button, "Button", "Tappable button"},
    {:icon, "Icon", "Icon element"},
    {:divider, "Divider", "Horizontal divider line"},
    {:spacer, "Spacer", "Flexible spacer"},
    {:text_field, "TextField", "Text input field"},
    {:toggle, "Toggle", "Toggle switch"},
    {:slider, "Slider", "Range slider"},
    {:switch, "Switch", "On/off switch"},
    {:image, "Image", "Image view"},
    {:video, "Video", "Video player"},
    {:activity_indicator, "ActivityIndicator", "Loading spinner"},
    {:progress_bar, "ProgressBar", "Progress indicator"},
    {:status_bar, "StatusBar", "Status bar"},
    {:refresh_control, "RefreshControl", "Pull-to-refresh"},
    {:webview, "WebView", "Embedded web view"},
    {:camera_preview, "CameraPreview", "Camera preview"},
    {:native_view, "NativeView", "Custom native view"},
    {:tab_bar, "TabBar", "Tab navigation bar"},
    {:list, "List", "List container"}
  ]

  @component_specs %{
    column: [
      {:padding, :atom, nil},
      {:gap, :atom, nil},
      {:background, :atom, nil},
      {:border_color, :atom, nil},
      {:border_width, :integer, nil},
      {:corner_radius, :integer, nil},
      {:fill_width, :boolean, false},
      {:width, :integer, nil},
      {:height, :integer, nil},
      {:on_tap, :event, nil},
      {:on_long_press, :event, nil}
    ],
    row: [
      {:padding, :atom, nil},
      {:gap, :atom, nil},
      {:background, :atom, nil},
      {:border_color, :atom, nil},
      {:border_width, :integer, nil},
      {:corner_radius, :integer, nil},
      {:fill_width, :boolean, false},
      {:width, :integer, nil},
      {:height, :integer, nil},
      {:on_tap, :event, nil},
      {:on_long_press, :event, nil}
    ],
    box: [
      {:padding, :atom, nil},
      {:background, :atom, nil},
      {:border_color, :atom, nil},
      {:border_width, :integer, nil},
      {:corner_radius, :integer, nil},
      {:fill_width, :boolean, false},
      {:width, :integer, nil},
      {:height, :integer, nil},
      {:on_tap, :event, nil},
      {:on_long_press, :event, nil},
      {:draggable, :boolean, false},
      {:droppable, :boolean, false}
    ],
    scroll: [
      {:padding, :atom, nil},
      {:gap, :atom, nil},
      {:background, :atom, nil},
      {:fill_width, :boolean, false},
      {:width, :integer, nil},
      {:height, :integer, nil}
    ],
    modal: [
      {:padding, :atom, nil},
      {:background, :atom, nil},
      {:corner_radius, :integer, nil},
      {:on_dismiss, :event, nil}
    ],
    pressable: [
      {:padding, :atom, nil},
      {:background, :atom, nil},
      {:corner_radius, :integer, nil},
      {:on_tap, :event, nil},
      {:on_long_press, :event, nil}
    ],
    safe_area: [
      {:padding, :atom, nil},
      {:background, :atom, nil}
    ],
    text: [
      {:text, :string, "Text"},
      {:text_color, :atom, nil},
      {:text_size, :atom, nil},
      {:font_weight, :atom, nil},
      {:text_align, :atom, nil},
      {:italic, :boolean, false},
      {:padding, :atom, nil},
      {:background, :atom, nil},
      {:corner_radius, :integer, nil},
      {:fill_width, :boolean, false},
      {:on_tap, :event, nil}
    ],
    button: [
      {:text, :string, "Button"},
      {:on_tap, :event, nil},
      {:disabled, :boolean, false},
      {:text_color, :atom, nil},
      {:text_size, :atom, nil},
      {:font_weight, :atom, nil},
      {:background, :atom, nil},
      {:padding, :atom, nil},
      {:corner_radius, :integer, nil},
      {:fill_width, :boolean, false}
    ],
    icon: [
      {:name, :atom, :star},
      {:text_color, :atom, nil},
      {:text_size, :atom, nil},
      {:on_tap, :event, nil}
    ],
    divider: [
      {:border_color, :atom, nil},
      {:padding, :atom, nil}
    ],
    spacer: [],
    text_field: [
      {:placeholder, :string, ""},
      {:value, :string, nil},
      {:on_change, :event, nil},
      {:on_focus, :event, nil},
      {:on_blur, :event, nil},
      {:text_color, :atom, nil},
      {:text_size, :atom, nil},
      {:background, :atom, nil},
      {:corner_radius, :integer, nil},
      {:fill_width, :boolean, false}
    ],
    toggle: [
      {:on_tap, :event, nil},
      {:text_color, :atom, nil},
      {:text_size, :atom, nil}
    ],
    slider: [
      {:value, :integer, 50},
      {:on_change, :event, nil},
      {:fill_width, :boolean, false}
    ],
    switch: [
      {:on_tap, :event, nil},
      {:text_color, :atom, nil}
    ],
    image: [
      {:src, :string, ""},
      {:fill_width, :boolean, false},
      {:width, :integer, nil},
      {:height, :integer, nil},
      {:corner_radius, :integer, nil},
      {:on_tap, :event, nil}
    ],
    video: [
      {:src, :string, ""},
      {:fill_width, :boolean, false},
      {:width, :integer, nil},
      {:height, :integer, nil}
    ],
    activity_indicator: [],
    progress_bar: [
      {:value, :integer, 0},
      {:fill_width, :boolean, false},
      {:corner_radius, :integer, nil}
    ],
    status_bar: [
      {:background, :atom, nil},
      {:text_color, :atom, nil}
    ],
    refresh_control: [
      {:on_refresh, :event, nil}
    ],
    webview: [
      {:src, :string, ""},
      {:fill_width, :boolean, false},
      {:width, :integer, nil},
      {:height, :integer, nil}
    ],
    camera_preview: [],
    native_view: [
      {:view_type, :string, ""},
      {:fill_width, :boolean, false},
      {:width, :integer, nil},
      {:height, :integer, nil}
    ],
    tab_bar: [
      {:on_tab_select, :event, nil},
      {:background, :atom, nil},
      {:text_color, :atom, nil}
    ],
    list: [
      {:padding, :atom, nil},
      {:gap, :atom, nil},
      {:background, :atom, nil},
      {:fill_width, :boolean, false},
      {:on_end_reached, :event, nil}
    ]
  }

  # ── LiveView callbacks ──────────────────────────────────────────────────────

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       tree: empty_root(),
       selected_id: nil,
       code_style: :dsl,
       module_name: "MyApp.HomeScreen",
       show_code: true,
       drag_type: nil,
       id_counter: 1
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="design-canvas" class="design-canvas-root" phx-hook="DesignCanvas">
      <style><%= raw(canvas_css()) %></style>
      <.header_bar show_code={@show_code} module_name={@module_name} />
      <div class="canvas-body">
        <.palette />
        <.design_canvas tree={@tree} selected_id={@selected_id} />
        <.property_editor tree={@tree} selected_id={@selected_id} />
      </div>
      <%= if @show_code do %>
        <.code_panel tree={@tree} code_style={@code_style} module_name={@module_name} />
      <% end %>
      <.canvas_footer module_name={@module_name} />
    </div>
    """
  end

  # ── Component: Header Bar ────────────────────────────────────────────────────

  attr(:show_code, :boolean, required: true)
  attr(:module_name, :string, required: true)

  def header_bar(assigns) do
    ~H"""
    <div class="canvas-header">
      <div class="canvas-header-left">
        <span class="canvas-logo">◆</span>
        <span class="canvas-title">Dala Preview Designer</span>
      </div>
      <div class="canvas-header-right">
        <span class="code-style-label">DSL</span>
        <button class="header-btn" phx-click="toggle_code">
          <%= if @show_code, do: "Hide Code", else: "Show Code" %>
        </button>
        <button class="header-btn danger" phx-click="clear_canvas">Clear</button>
      </div>
    </div>
    """
  end

  # ── Component: Palette ───────────────────────────────────────────────────────

  def palette(assigns) do
    ~H"""
    <div class="palette">
      <div class="palette-section">
        <div class="palette-section-title">Layout</div>
        <div class="palette-items">
          <%= for {type, label, _desc} <- layout_palette() do %>
            <div
              class="palette-item palette-item--container"
              draggable="true"
              phx-click="add_node"
              phx-value-type={to_string(type)}
              data-drag-type={to_string(type)}
            >
              <span class="palette-icon">⊞</span>
              <span class="palette-label"><%= label %></span>
            </div>
          <% end %>
        </div>
      </div>

      <div class="palette-section">
        <div class="palette-section-title">Components</div>
        <div class="palette-items">
          <%= for {type, label, _desc} <- leaf_palette() do %>
            <div
              class="palette-item palette-item--leaf"
              draggable="true"
              phx-click="add_node"
              phx-value-type={to_string(type)}
              data-drag-type={to_string(type)}
            >
              <span class="palette-icon">▫</span>
              <span class="palette-label"><%= label %></span>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # ── Component: Design Canvas ─────────────────────────────────────────────────

  attr(:tree, :map, required: true)
  attr(:selected_id, :any, default: nil)

  def design_canvas(assigns) do
    ~H"""
    <div class="design-canvas">
      <div class="canvas-phone-frame">
        <div class="canvas-phone-notch"></div>
        <div class="canvas-phone-screen">
          <.live_preview tree={@tree} />
        </div>
      </div>
      <div class="canvas-tree-view">
        <div class="tree-view-header">Tree</div>
        <div class="tree-view-content">
          <.tree_node node={@tree} selected_id={@selected_id} depth={0} />
        </div>
      </div>
    </div>
    """
  end

  # ── Component: Tree Node ─────────────────────────────────────────────────────

  attr(:node, :map, required: true)
  attr(:selected_id, :any, default: nil)
  attr(:depth, :integer, default: 0)

  def tree_node(assigns) do
    ~H"""
    <div
      class={"tree-node #{tree_node_classes(@node, @selected_id)}"}
      phx-click="select_node"
      phx-value-id={@node.id}
    >
      <div class="tree-node-header" style={"padding-left: #{@depth * 16 + 8}px"}>
        <span class="tree-node-type"><%= format_type(@node.type) %></span>
        <%= if @node.props[:text] do %>
          <span class="tree-node-text">"<%= truncate(@node.props[:text], 20) %>"</span>
        <% end %>
        <%= if container_type?(@node.type) do %>
          <span class="tree-node-badge">container</span>
        <% end %>
      </div>
      <%= if container_type?(@node.type) and has_children?(@node) do %>
        <div
          class="tree-node-children drop-zone"
          data-drop-target={@node.id}
        >
          <%= for child <- @node.children do %>
            <.tree_node node={child} selected_id={@selected_id} depth={@depth + 1} />
          <% end %>
        </div>
      <% end %>
      <%= if container_type?(@node.type) and not has_children?(@node) do %>
        <div
          class="tree-node-children tree-node-empty drop-zone"
          data-drop-target={@node.id}
        >
          Drop here
        </div>
      <% end %>
    </div>
    """
  end

  # ── Component: Property Editor ───────────────────────────────────────────────

  attr(:tree, :map, required: true)
  attr(:selected_id, :any, default: nil)

  def property_editor(assigns) do
    ~H"""
    <div class="property-editor">
      <div class="property-editor-header">Properties</div>
      <%= if @selected_id do %>
        <% node = find_node(@tree, @selected_id) %>
        <%= if node do %>
          <.prop_editor node={node} />
        <% else %>
          <div class="property-editor-empty">Node not found</div>
        <% end %>
      <% else %>
        <div class="property-editor-empty">Select a node to edit its properties</div>
      <% end %>
    </div>
    """
  end

  # ── Component: Prop Editor ───────────────────────────────────────────────────

  attr(:node, :map, required: true)

  def prop_editor(assigns) do
    ~H"""
    <div class="prop-editor">
      <div class="prop-editor-type">
        <span class="prop-type-badge"><%= format_type(@node.type) %></span>
        <button class="prop-delete-btn" phx-click="delete_node" phx-value-id={@node.id}>
          ✕ Delete
        </button>
      </div>

      <div class="prop-editor-fields">
        <%= for {prop_name, prop_type, default} <- prop_defs_for(@node.type) do %>
          <.prop_field
            node={@node}
            prop_name={prop_name}
            prop_type={prop_type}
            default={default}
          />
        <% end %>
      </div>
    </div>
    """
  end

  # ── Component: Prop Field ────────────────────────────────────────────────────

  attr(:node, :map, required: true)
  attr(:prop_name, :atom, required: true)
  attr(:prop_type, :atom, required: true)
  attr(:default, :any, default: nil)

  def prop_field(assigns) do
    %{node: node, prop_name: prop_name, prop_type: _prop_type, default: default} = assigns
    current_value = Map.get(node.props, prop_name, default)

    assigns =
      assign(assigns,
        current_value: current_value,
        input_id: "prop-#{node.id}-#{prop_name}",
        form_id: "form-#{node.id}-#{prop_name}"
      )

    ~H"""
    <div class="prop-field">
      <label class="prop-label" for={@input_id}><%= @prop_name %></label>
      <%= case @prop_type do %>
        <% :string -> %>
          <form id={@form_id} phx-submit="update_prop" phx-change="update_prop">
            <input type="hidden" name="node_id" value={@node.id} />
            <input type="hidden" name="prop" value={to_string(@prop_name)} />
            <input
              type="text"
              id={@input_id}
              name="value"
              class="prop-input"
              value={@current_value || ""}
            />
          </form>
        <% :atom -> %>
          <form id={@form_id} phx-submit="update_prop" phx-change="update_prop">
            <input type="hidden" name="node_id" value={@node.id} />
            <input type="hidden" name="prop" value={to_string(@prop_name)} />
            <input
              type="text"
              id={@input_id}
              name="value"
              class="prop-input"
              value={@current_value || ""}
            />
          </form>
        <% :integer -> %>
          <form id={@form_id} phx-submit="update_prop" phx-change="update_prop">
            <input type="hidden" name="node_id" value={@node.id} />
            <input type="hidden" name="prop" value={to_string(@prop_name)} />
            <input
              type="number"
              id={@input_id}
              name="value"
              class="prop-input prop-input--number"
              value={to_string(@current_value || "")}
            />
          </form>
        <% :float -> %>
          <form id={@form_id} phx-submit="update_prop" phx-change="update_prop">
            <input type="hidden" name="node_id" value={@node.id} />
            <input type="hidden" name="prop" value={to_string(@prop_name)} />
            <input
              type="number"
              id={@input_id}
              name="value"
              class="prop-input prop-input--number"
              step="0.1"
              value={to_string(@current_value || "")}
            />
          </form>
        <% :boolean -> %>
          <input
            type="checkbox"
            id={@input_id}
            class="prop-checkbox"
            checked={@current_value == true}
            phx-click="update_prop"
            phx-value-id={@node.id}
            phx-value-prop={to_string(@prop_name)}
            phx-value-value={to_string(!@current_value)}
          />
        <% :event -> %>
          <form id={@form_id} phx-submit="update_prop" phx-change="update_prop">
            <input type="hidden" name="node_id" value={@node.id} />
            <input type="hidden" name="prop" value={to_string(@prop_name)} />
            <input
              type="text"
              id={@input_id}
              name="value"
              class="prop-input prop-input--event"
              value={@current_value || ""}
              placeholder="handler_name"
            />
          </form>
        <% _ -> %>
          <form id={@form_id} phx-submit="update_prop" phx-change="update_prop">
            <input type="hidden" name="node_id" value={@node.id} />
            <input type="hidden" name="prop" value={to_string(@prop_name)} />
            <input
              type="text"
              id={@input_id}
              name="value"
              class="prop-input"
              value={inspect(@current_value)}
            />
          </form>
      <% end %>
    </div>
    """
  end

  # ── Component: Code Panel ────────────────────────────────────────────────────

  attr(:tree, :map, required: true)
  attr(:code_style, :atom, required: true)
  attr(:module_name, :string, required: true)

  def code_panel(assigns) do
    ~H"""
    <div class="code-panel">
      <div class="code-panel-header">
        <span>Generated Code</span>
        <button class="code-copy-btn" phx-click="copy_code">Copy</button>
      </div>
      <pre class="code-panel-content"><code><%= generate_code(@tree, @code_style, @module_name) %></code></pre>
    </div>
    """
  end

  # ── Component: Live Preview ──────────────────────────────────────────────────

  attr(:tree, :map, required: true)

  def live_preview(assigns) do
    ~H"""
    <div class="live-preview">
      <%= raw(render_preview_tree(@tree)) %>
    </div>
    """
  end

  # ── Component: Canvas Footer ─────────────────────────────────────────────────

  attr(:module_name, :string, required: true)

  def canvas_footer(assigns) do
    ~H"""
    <div class="canvas-footer">
      <label class="module-name-label">Module:</label>
      <form phx-submit="set_module_name" phx-change="set_module_name" style="display: flex; flex: 1; max-width: 300px;">
        <input
          type="text"
          name="value"
          class="module-name-input"
          value={@module_name}
        />
      </form>
    </div>
    """
  end

  # ── LiveView event handlers ──────────────────────────────────────────────────

  @impl true
  def handle_event("select_node", %{"id" => id}, socket) do
    {:noreply, assign(socket, selected_id: id)}
  end

  def handle_event("deselect", _params, socket) do
    {:noreply, assign(socket, selected_id: nil)}
  end

  def handle_event("update_prop", params, socket) do
    %{"node_id" => id, "prop" => prop_str, "value" => value_str} = params
    prop = String.to_atom(prop_str)
    tree = socket.assigns.tree

    case find_node(tree, id) do
      nil ->
        {:noreply, socket}

      node ->
        spec = Map.get(@component_specs, node.type, [])
        prop_def = Enum.find(spec, fn {p, _, _} -> p == prop end)
        parsed = parse_prop_value(value_str, prop_def)

        updated_tree =
          update_node_in_tree(tree, id, fn n ->
            %{n | props: Map.put(n.props, prop, parsed)}
          end)

        {:noreply, assign(socket, tree: updated_tree)}
    end
  end

  def handle_event("delete_node", %{"id" => id}, socket) do
    tree = socket.assigns.tree

    if tree.id == id do
      {:noreply, assign(socket, tree: empty_root(), selected_id: nil)}
    else
      updated_tree = remove_node_from_tree(tree, id)
      {:noreply, assign(socket, tree: updated_tree, selected_id: nil)}
    end
  end

  def handle_event("add_node", %{"type" => type_str}, socket) do
    type = String.to_atom(type_str)
    new_node = make_node(type, socket.assigns.id_counter)
    tree = socket.assigns.tree
    updated_tree = add_node_to_tree(tree, tree.id, new_node)
    {:noreply, assign(socket, tree: updated_tree, id_counter: socket.assigns.id_counter + 1)}
  end

  def handle_event("drop_on_node", %{"target_id" => target_id, "type" => type_str}, socket) do
    type = String.to_atom(type_str)
    new_node = make_node(type, socket.assigns.id_counter)
    tree = socket.assigns.tree

    case find_node(tree, target_id) do
      %{type: t} when t in @container_types ->
        updated_tree = add_node_to_tree(tree, target_id, new_node)
        {:noreply, assign(socket, tree: updated_tree, id_counter: socket.assigns.id_counter + 1)}

      _ ->
        updated_tree = add_node_to_tree(tree, tree.id, new_node)
        {:noreply, assign(socket, tree: updated_tree, id_counter: socket.assigns.id_counter + 1)}
    end
  end

  def handle_event("move_node", %{"node_id" => node_id, "target_id" => target_id}, socket) do
    tree = socket.assigns.tree

    case find_node(tree, node_id) do
      nil ->
        {:noreply, socket}

      node ->
        tree_without = remove_node_from_tree(tree, node_id)
        updated_tree = add_node_to_tree(tree_without, target_id, node)
        {:noreply, assign(socket, tree: updated_tree)}
    end
  end

  def handle_event("toggle_code", _params, socket) do
    {:noreply, assign(socket, show_code: !socket.assigns.show_code)}
  end

  def handle_event("set_module_name", params, socket) do
    name = params["value"] || params["module_name"] || socket.assigns.module_name

    if is_binary(name) and name != "" do
      {:noreply, assign(socket, module_name: name)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("clear_canvas", _params, socket) do
    {:noreply, assign(socket, tree: empty_root(), selected_id: nil, id_counter: 1)}
  end

  # ── Tree manipulation helpers ────────────────────────────────────────────────

  defp empty_root do
    %{
      type: :column,
      props: %{padding: :md, gap: :sm},
      children: [],
      id: "node_0"
    }
  end

  defp make_node(type, counter) do
    %{
      type: type,
      props: default_props(type),
      children: if(type in @container_types, do: [], else: []),
      id: "node_#{counter}"
    }
  end

  defp add_node_to_tree(tree, target_id, new_node) do
    if tree.id == target_id and tree.type in @container_types do
      Map.update(tree, :children, [new_node], &(&1 ++ [new_node]))
    else
      Map.update(tree, :children, [], fn children ->
        Enum.map(children, fn child ->
          add_node_to_tree(child, target_id, new_node)
        end)
      end)
    end
  end

  defp remove_node_from_tree(tree, node_id) do
    Map.update(tree, :children, [], fn children ->
      children
      |> Enum.reject(fn child -> child.id == node_id end)
      |> Enum.map(fn child -> remove_node_from_tree(child, node_id) end)
    end)
  end

  defp update_node_in_tree(tree, node_id, update_fn) do
    if tree.id == node_id do
      update_fn.(tree)
    else
      Map.update(tree, :children, [], fn children ->
        Enum.map(children, &update_node_in_tree(&1, node_id, update_fn))
      end)
    end
  end

  defp find_node(tree, node_id) do
    cond do
      tree.id == node_id -> tree
      tree[:children] -> Enum.find_value(tree.children, &find_node(&1, node_id))
      true -> nil
    end
  end

  defp strip_ids(tree) do
    tree
    |> Map.delete(:id)
    |> Map.update(:children, [], fn children ->
      Enum.map(children, &strip_ids/1)
    end)
  end

  defp default_props(:text), do: %{text: "Text"}
  defp default_props(:button), do: %{text: "Button"}
  defp default_props(:icon), do: %{name: :star}
  defp default_props(:text_field), do: %{placeholder: "Type here..."}
  defp default_props(:slider), do: %{value: 50}
  defp default_props(:progress_bar), do: %{value: 0}
  defp default_props(:image), do: %{src: "https://via.placeholder.com/150"}
  defp default_props(:video), do: %{src: ""}
  defp default_props(:column), do: %{padding: :sm, gap: :sm}
  defp default_props(:row), do: %{gap: :sm}
  defp default_props(:box), do: %{padding: :sm}
  defp default_props(:scroll), do: %{}
  defp default_props(:modal), do: %{}
  defp default_props(:pressable), do: %{}
  defp default_props(:safe_area), do: %{}
  defp default_props(:tab_bar), do: %{}
  defp default_props(:list), do: %{}
  defp default_props(_), do: %{}

  defp container_type?(type), do: type in @container_types
  defp has_children?(node), do: node[:children] != nil and node.children != []

  # ── Rendering helpers ────────────────────────────────────────────────────────

  defp layout_palette, do: @layout_palette
  defp leaf_palette, do: @leaf_palette

  defp format_type(:text_field), do: "TextField"
  defp format_type(:activity_indicator), do: "ActivityIndicator"
  defp format_type(:progress_bar), do: "ProgressBar"
  defp format_type(:status_bar), do: "StatusBar"
  defp format_type(:refresh_control), do: "RefreshControl"
  defp format_type(:camera_preview), do: "CameraPreview"
  defp format_type(:native_view), do: "NativeView"
  defp format_type(:tab_bar), do: "TabBar"
  defp format_type(:safe_area), do: "SafeArea"

  defp format_type(type) when is_atom(type) do
    type
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join("")
  end

  defp truncate(text, max_len) when is_binary(text) do
    if String.length(text) > max_len do
      String.slice(text, 0, max_len) <> "…"
    else
      text
    end
  end

  defp truncate(_, _), do: ""

  defp tree_node_classes(node, selected_id) do
    base = if container_type?(node.type), do: "tree-node--container", else: "tree-node--leaf"
    selected = if node.id == selected_id, do: "tree-node--selected", else: ""
    [base, selected] |> Enum.filter(&(&1 != "")) |> Enum.join(" ")
  end

  defp prop_defs_for(type) do
    Map.get(@component_specs, type, [])
  end

  defp parse_prop_value(value_str, nil), do: parse_prop_value(value_str)
  defp parse_prop_value(value_str, {_name, :string, _default}), do: value_str

  defp parse_prop_value(value_str, {_name, :atom, _default}) do
    if value_str == "" or is_nil(value_str) do
      nil
    else
      String.to_atom(String.replace(value_str, ":", ""))
    end
  end

  defp parse_prop_value(value_str, {_name, :integer, _default}) do
    case Integer.parse(value_str || "") do
      {n, ""} -> n
      _ -> nil
    end
  end

  defp parse_prop_value(value_str, {_name, :float, _default}) do
    case Float.parse(value_str || "") do
      {f, ""} -> f
      _ -> nil
    end
  end

  defp parse_prop_value("true", {_name, :boolean, _default}), do: true
  defp parse_prop_value("false", {_name, :boolean, _default}), do: false
  defp parse_prop_value(value_str, {_name, :event, _default}), do: parse_prop_value(value_str)
  defp parse_prop_value(value_str, _), do: parse_prop_value(value_str)

  defp parse_prop_value("true"), do: true
  defp parse_prop_value("false"), do: false

  defp parse_prop_value(str) when is_binary(str) do
    case Integer.parse(str) do
      {n, ""} -> n
      _ -> str
    end
  end

  defp generate_code(tree, :dsl, module_name) do
    Codegen.generate_dsl(module_name, strip_ids(tree))
  end

  # ── Preview rendering ────────────────────────────────────────────────────────

  defp render_preview_tree(%{type: type, props: props, children: children}) do
    render_preview_component(type, props, children)
  end

  defp render_preview_tree(_), do: ""

  defp render_preview_component(:column, props, children) do
    style = build_preview_style(props)
    "<div class=\"dala-column\" style=\"#{style}\">#{render_preview_children(children)}</div>"
  end

  defp render_preview_component(:row, props, children) do
    style = build_preview_style(props)
    "<div class=\"dala-row\" style=\"#{style}\">#{render_preview_children(children)}</div>"
  end

  defp render_preview_component(:text, props, _children) do
    text = escape_html(props[:text] || "")
    style = build_preview_text_style(props)
    "<div class=\"dala-text\" style=\"#{style}\">#{text}</div>"
  end

  defp render_preview_component(:button, props, _children) do
    text = escape_html(props[:text] || "Button")
    "<button class=\"dala-button\">#{text}</button>"
  end

  defp render_preview_component(:box, props, children) do
    style = build_preview_style(props)
    "<div class=\"dala-box\" style=\"#{style}\">#{render_preview_children(children)}</div>"
  end

  defp render_preview_component(:scroll, props, children) do
    style = build_preview_style(props) <> " overflow-y: auto;"
    "<div class=\"dala-scroll\" style=\"#{style}\">#{render_preview_children(children)}</div>"
  end

  defp render_preview_component(:modal, props, children) do
    style = build_preview_style(props)
    "<div class=\"dala-modal\" style=\"#{style}\">#{render_preview_children(children)}</div>"
  end

  defp render_preview_component(:pressable, props, children) do
    style = build_preview_style(props) <> " cursor: pointer;"
    "<div class=\"dala-pressable\" style=\"#{style}\">#{render_preview_children(children)}</div>"
  end

  defp render_preview_component(:safe_area, props, children) do
    style = build_preview_style(props)
    "<div class=\"dala-safe-area\" style=\"#{style}\">#{render_preview_children(children)}</div>"
  end

  defp render_preview_component(:spacer, _props, _children) do
    "<div class=\"dala-spacer\" style=\"flex: 1; min-height: 16px;\"></div>"
  end

  defp render_preview_component(:divider, _props, _children) do
    "<hr class=\"dala-divider\" />"
  end

  defp render_preview_component(:icon, props, _children) do
    name = props[:name] || "star"
    "<span class=\"dala-icon\" data-icon=\"#{name}\">[#{name}]</span>"
  end

  defp render_preview_component(:toggle, _props, _children) do
    "<div class=\"dala-toggle\" style=\"cursor: pointer;\">Toggle</div>"
  end

  defp render_preview_component(:switch, _props, _children) do
    "<div class=\"dala-switch\" style=\"cursor: pointer;\">Switch</div>"
  end

  defp render_preview_component(:slider, props, _children) do
    value = props[:value] || 0

    "<input type=\"range\" class=\"dala-slider\" min=\"0\" max=\"100\" value=\"#{value}\" /><span>#{value}%</span>"
  end

  defp render_preview_component(:progress_bar, props, _children) do
    value = props[:value] || 0

    "<div class=\"dala-progress-bar\" style=\"width: #{value}%; background: #2196F3; height: 4px; border-radius: 2px;\">#{value}%</div>"
  end

  defp render_preview_component(:text_field, props, _children) do
    placeholder = props[:placeholder] || ""

    "<input type=\"text\" class=\"dala-text-field\" placeholder=\"#{escape_html(placeholder)}\" />"
  end

  defp render_preview_component(:list, props, children) do
    style = build_preview_style(props)
    "<div class=\"dala-list\" style=\"#{style}\">#{render_preview_children(children)}</div>"
  end

  defp render_preview_component(:image, props, _children) do
    src = props[:src] || ""

    "<div class=\"dala-image\" style=\"background: #e0e0e0; min-height: 80px; display: flex; align-items: center; justify-content: center; color: #999;\">📷 #{escape_html(src)}</div>"
  end

  defp render_preview_component(:video, _props, _children) do
    "<div class=\"dala-video\" style=\"background: #1a1a1a; min-height: 80px; display: flex; align-items: center; justify-content: center; color: #666;\">▶ Video</div>"
  end

  defp render_preview_component(:activity_indicator, _props, _children) do
    "<div class=\"dala-activity-indicator\" style=\"display: flex; align-items: center; justify-content: center; padding: 16px;\">⏳</div>"
  end

  defp render_preview_component(:status_bar, _props, _children) do
    "<div class=\"dala-status-bar\" style=\"background: #f5f5f5; padding: 4px 8px; font-size: 10px; color: #666;\">Status Bar</div>"
  end

  defp render_preview_component(:refresh_control, _props, _children) do
    "<div class=\"dala-refresh-control\" style=\"text-align: center; padding: 8px; color: #999;\">↻ Pull to refresh</div>"
  end

  defp render_preview_component(:webview, props, _children) do
    src = props[:src] || ""

    "<div class=\"dala-webview\" style=\"background: #f0f0f0; min-height: 60px; display: flex; align-items: center; justify-content: center; color: #666; border: 1px solid #ddd;\">🌐 #{escape_html(src)}</div>"
  end

  defp render_preview_component(:camera_preview, _props, _children) do
    "<div class=\"dala-camera-preview\" style=\"background: #222; min-height: 80px; display: flex; align-items: center; justify-content: center; color: #666;\">📷 Camera</div>"
  end

  defp render_preview_component(:native_view, _props, _children) do
    "<div class=\"dala-native-view\" style=\"background: #f5f5f5; min-height: 40px; display: flex; align-items: center; justify-content: center; color: #666; border: 1px dashed #ccc;\">Native View</div>"
  end

  defp render_preview_component(:tab_bar, _props, _children) do
    "<div class=\"dala-tab-bar\" style=\"display: flex; background: #f5f5f5; padding: 8px; justify-content: space-around;\">Tab Bar</div>"
  end

  defp render_preview_component(type, props, children) do
    style = build_preview_style(props)

    "<div class=\"dala-unknown\" style=\"#{style}\">#{render_preview_children(children)}<small>Unknown: #{type}</small></div>"
  end

  defp render_preview_children(children) when is_list(children) do
    Enum.map(children, &render_preview_tree/1) |> Enum.join("\n")
  end

  defp render_preview_children(_), do: ""

  defp build_preview_style(props) do
    style_keys = [
      :padding,
      :padding_top,
      :padding_right,
      :padding_bottom,
      :padding_left,
      :gap,
      :background,
      :border_color,
      :border_width,
      :corner_radius,
      :width,
      :height
    ]

    props
    |> Enum.filter(fn {k, _} -> k in style_keys end)
    |> Enum.map(fn {k, v} -> "#{preview_css_property(k)}: #{preview_css_value(v)};" end)
    |> Enum.join(" ")
  end

  defp build_preview_text_style(props) do
    styles = []

    styles =
      if props[:text_size],
        do: ["font-size: #{preview_text_size(props[:text_size])}px" | styles],
        else: styles

    styles =
      if props[:text_color],
        do: ["color: #{preview_color(props[:text_color])}" | styles],
        else: styles

    styles =
      if props[:font_weight], do: ["font-weight: #{props[:font_weight]}" | styles], else: styles

    styles =
      if props[:text_align], do: ["text-align: #{props[:text_align]}" | styles], else: styles

    Enum.join(styles, "; ")
  end

  defp preview_css_property(:padding), do: "padding"
  defp preview_css_property(:padding_top), do: "padding-top"
  defp preview_css_property(:padding_right), do: "padding-right"
  defp preview_css_property(:padding_bottom), do: "padding-bottom"
  defp preview_css_property(:padding_left), do: "padding-left"
  defp preview_css_property(:gap), do: "gap"
  defp preview_css_property(:background), do: "background"
  defp preview_css_property(:border_color), do: "border-color"
  defp preview_css_property(:border_width), do: "border-width"
  defp preview_css_property(:corner_radius), do: "border-radius"
  defp preview_css_property(:width), do: "width"
  defp preview_css_property(:height), do: "height"
  defp preview_css_property(_), do: ""

  defp preview_css_value(:space_xs), do: "4px"
  defp preview_css_value(:space_sm), do: "8px"
  defp preview_css_value(:space_md), do: "16px"
  defp preview_css_value(:space_lg), do: "24px"
  defp preview_css_value(:space_xl), do: "32px"
  defp preview_css_value(:radius_sm), do: "4px"
  defp preview_css_value(:radius_md), do: "8px"
  defp preview_css_value(:radius_lg), do: "12px"
  defp preview_css_value(:radius_pill), do: "999px"
  defp preview_css_value(:primary), do: "#2196F3"
  defp preview_css_value(:surface), do: "#FFFFFF"
  defp preview_css_value(:on_surface), do: "#212121"
  defp preview_css_value(:on_primary), do: "#FFFFFF"
  defp preview_css_value(value) when is_binary(value), do: value
  defp preview_css_value(value), do: "#{value}"

  defp preview_text_size(:xl), do: 24
  defp preview_text_size(:lg), do: 18
  defp preview_text_size(:md), do: 14
  defp preview_text_size(:sm), do: 12
  defp preview_text_size(:xs), do: 10
  defp preview_text_size(size) when is_integer(size), do: size
  defp preview_text_size(_), do: 14

  defp preview_color(:primary), do: "#2196F3"
  defp preview_color(:on_primary), do: "#FFFFFF"
  defp preview_color(:on_surface), do: "#212121"
  defp preview_color(:surface), do: "#FFFFFF"
  defp preview_color(color) when is_binary(color), do: color
  defp preview_color(color), do: "##{color}"

  defp escape_html(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp escape_html(other), do: inspect(other)

  # ── CSS ──────────────────────────────────────────────────────────────────────

  defp canvas_css do
    """
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    .design-canvas-root {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      display: flex; flex-direction: column; height: 100vh;
      background: #1a1a2e; color: #e0e0e0;
    }
    .canvas-header {
      display: flex; justify-content: space-between; align-items: center;
      padding: 8px 16px; background: #16213e; border-bottom: 1px solid #0f3460;
    }
    .canvas-header-left { display: flex; align-items: center; gap: 8px; }
    .canvas-logo { font-size: 20px; color: #2196F3; }
    .canvas-title { font-size: 14px; font-weight: 600; color: #e0e0e0; }
    .canvas-header-right { display: flex; align-items: center; gap: 8px; }

    .code-style-label {
      padding: 4px 12px; background: #2196F3; color: white;
      border-radius: 6px; font-size: 12px; font-weight: 600;
    }

    .header-btn {
      padding: 4px 12px; border: 1px solid #0f3460; background: transparent;
      color: #e0e0e0; border-radius: 4px; cursor: pointer; font-size: 12px;
    }
    .header-btn:hover { background: #0f3460; }
    .header-btn.danger { border-color: #e53935; color: #e53935; }
    .header-btn.danger:hover { background: #e53935; color: white; }

    .canvas-body { display: flex; flex: 1; overflow: hidden; }

    /* Palette */
    .palette {
      width: 180px; background: #16213e; border-right: 1px solid #0f3460;
      overflow-y: auto; padding: 8px;
    }
    .palette-section { margin-bottom: 12px; }
    .palette-section-title {
      font-size: 10px; text-transform: uppercase; letter-spacing: 1px;
      color: #888; margin-bottom: 6px; padding: 0 4px;
    }
    .palette-items { display: flex; flex-direction: column; gap: 2px; }
    .palette-item {
      display: flex; align-items: center; gap: 6px; padding: 6px 8px;
      border-radius: 4px; cursor: pointer; font-size: 12px;
      transition: background 0.15s; user-select: none;
    }
    .palette-item:hover { background: #0f3460; }
    .palette-item--container .palette-icon { color: #2196F3; }
    .palette-item--leaf .palette-icon { color: #66bb6a; }
    .palette-icon { font-size: 14px; width: 16px; text-align: center; }
    .palette-label { color: #ccc; }

    /* Design Canvas */
    .design-canvas { flex: 1; display: flex; overflow: hidden; }
    .canvas-phone-frame {
      flex: 1; display: flex; flex-direction: column; align-items: center;
      justify-content: center; padding: 20px;
    }
    .canvas-phone-notch {
      width: 120px; height: 20px; background: #333; border-radius: 0 0 12px 12px;
      margin-bottom: -1px; position: relative; z-index: 1;
    }
    .canvas-phone-screen {
      width: 320px; height: 568px; background: white; border-radius: 0 0 16px 16px;
      overflow-y: auto; box-shadow: 0 4px 24px rgba(0,0,0,0.4);
      position: relative;
    }
    .live-preview {
      font-family: -apple-system, sans-serif; font-size: 14px; color: #212121;
      padding: 0; min-height: 100%;
    }

    /* Tree View */
    .canvas-tree-view {
      width: 240px; background: #16213e; border-left: 1px solid #0f3460;
      display: flex; flex-direction: column; overflow: hidden;
    }
    .tree-view-header {
      padding: 8px 12px; font-size: 11px; text-transform: uppercase;
      letter-spacing: 1px; color: #888; border-bottom: 1px solid #0f3460;
    }
    .tree-view-content { overflow-y: auto; flex: 1; padding: 4px; }

    .tree-node { cursor: pointer; border-radius: 4px; margin: 1px 0; }
    .tree-node:hover { background: rgba(33, 150, 243, 0.1); }
    .tree-node--selected { background: rgba(33, 150, 243, 0.2); outline: 1px solid #2196F3; }
    .tree-node-header {
      display: flex; align-items: center; gap: 6px; padding: 4px 8px;
      font-size: 12px; min-height: 28px;
    }
    .tree-node-type { font-weight: 600; color: #90caf9; }
    .tree-node-text { color: #aaa; font-style: italic; font-size: 11px; }
    .tree-node-badge {
      font-size: 9px; background: #0f3460; color: #64b5f6;
      padding: 1px 4px; border-radius: 3px;
    }
    .tree-node-children { border-left: 1px solid #0f3460; margin-left: 12px; }
    .tree-node-empty {
      padding: 8px 12px; color: #555; font-size: 11px; font-style: italic;
      border: 1px dashed #333; border-radius: 4px; margin: 4px 8px;
      text-align: center;
    }
    .drop-zone.drag-over {
      background: rgba(33, 150, 243, 0.15); border: 1px dashed #2196F3;
      border-radius: 4px;
    }

    /* Property Editor */
    .property-editor {
      width: 240px; background: #16213e; border-left: 1px solid #0f3460;
      display: flex; flex-direction: column; overflow: hidden;
    }
    .property-editor-header {
      padding: 8px 12px; font-size: 11px; text-transform: uppercase;
      letter-spacing: 1px; color: #888; border-bottom: 1px solid #0f3460;
    }
    .property-editor-empty {
      padding: 16px; color: #666; font-size: 12px; text-align: center;
    }

    .prop-editor { padding: 8px; }
    .prop-editor-type {
      display: flex; justify-content: space-between; align-items: center;
      margin-bottom: 12px; padding-bottom: 8px; border-bottom: 1px solid #0f3460;
    }
    .prop-type-badge {
      background: #0f3460; color: #90caf9; padding: 2px 8px;
      border-radius: 4px; font-size: 12px; font-weight: 600;
    }
    .prop-delete-btn {
      background: transparent; border: 1px solid #e53935; color: #e53935;
      padding: 2px 8px; border-radius: 4px; cursor: pointer; font-size: 11px;
    }
    .prop-delete-btn:hover { background: #e53935; color: white; }

    .prop-editor-fields { display: flex; flex-direction: column; gap: 8px; }
    .prop-field { display: flex; flex-direction: column; gap: 2px; }
    .prop-field form { display: flex; }
    .prop-label {
      font-size: 10px; text-transform: uppercase; letter-spacing: 0.5px;
      color: #888;
    }
    .prop-input {
      background: #0f3460; border: 1px solid #1a3a6e; color: #e0e0e0;
      padding: 4px 8px; border-radius: 4px; font-size: 12px; width: 100%;
    }
    .prop-input:focus { outline: none; border-color: #2196F3; }
    .prop-input--number { width: 80px; }
    .prop-input--event { font-family: monospace; }
    .prop-checkbox { width: 16px; height: 16px; accent-color: #2196F3; }

    /* Code Panel */
    .code-panel {
      background: #0d1117; border-top: 1px solid #0f3460; max-height: 250px;
      display: flex; flex-direction: column;
    }
    .code-panel-header {
      display: flex; justify-content: space-between; align-items: center;
      padding: 6px 12px; background: #161b22; border-bottom: 1px solid #0f3460;
    }
    .code-panel-header span { font-size: 11px; color: #888; text-transform: uppercase; letter-spacing: 1px; }
    .code-copy-btn {
      background: transparent; border: 1px solid #0f3460; color: #888;
      padding: 2px 8px; border-radius: 4px; cursor: pointer; font-size: 11px;
    }
    .code-copy-btn:hover { background: #0f3460; color: #e0e0e0; }
    .code-panel-content {
      flex: 1; overflow: auto; padding: 12px; margin: 0;
      font-family: "JetBrains Mono", "Fira Code", monospace; font-size: 12px;
      line-height: 1.5; color: #c9d1d9; white-space: pre;
    }

    /* Canvas Footer */
    .canvas-footer {
      display: flex; align-items: center; gap: 8px; padding: 6px 16px;
      background: #16213e; border-top: 1px solid #0f3460;
    }
    .module-name-label { font-size: 11px; color: #888; text-transform: uppercase; letter-spacing: 0.5px; }
    .module-name-input {
      background: #0f3460; border: 1px solid #1a3a6e; color: #e0e0e0;
      padding: 4px 8px; border-radius: 4px; font-size: 12px; flex: 1; max-width: 300px;
    }
    .module-name-input:focus { outline: none; border-color: #2196F3; }

    /* Dala preview styles (inside phone frame) */
    .live-preview .dala-column { display: flex; flex-direction: column; }
    .live-preview .dala-row { display: flex; flex-direction: row; align-items: center; }
    .live-preview .dala-text { padding: 2px 0; }
    .live-preview .dala-button {
      background: #2196F3; color: white; border: none; border-radius: 4px;
      padding: 6px 16px; font-size: 14px; cursor: pointer;
    }
    .live-preview .dala-box { display: flex; }
    .live-preview .dala-spacer { flex: 1; }
    .live-preview .dala-divider { border: none; border-top: 1px solid #e0e0e0; margin: 8px 0; }
    .live-preview .dala-icon { font-size: 16px; }
    .live-preview .dala-toggle {
      width: 40px; height: 20px; background: #ccc; border-radius: 10px;
      position: relative; cursor: pointer;
    }
    .live-preview .dala-switch { display: inline-block; }
    .live-preview .dala-slider { width: 100%; }
    .live-preview .dala-progress-bar {
      background: #2196F3; height: 4px; border-radius: 2px;
    }
    .live-preview .dala-text-field {
      border: 1px solid #ccc; border-radius: 4px; padding: 6px 8px;
      font-size: 14px; width: 100%;
    }
    .live-preview .dala-list { display: flex; flex-direction: column; }
    .live-preview .dala-list-item {
      padding: 8px; border-bottom: 1px solid #eee; cursor: pointer;
    }
    .live-preview .dala-unknown { padding: 4px; }
    """
  end

  # ── Drag-and-drop hook JS ────────────────────────────────────────────────────

  @doc false
  def hook_js do
    """
    const DesignCanvas = {
      mounted() {
        this.initDragDrop();
      },
      updated() {
        this.initDragDrop();
      },
      initDragDrop() {
        const root = this.el;
        root.querySelectorAll('.palette-item[draggable]').forEach(el => {
          el.addEventListener('dragstart', e => {
            e.dataTransfer.setData('text/plain', el.dataset.dragType);
            e.dataTransfer.effectAllowed = 'copy';
          });
        });
        root.querySelectorAll('.drop-zone').forEach(zone => {
          zone.addEventListener('dragover', e => {
            e.preventDefault();
            e.dataTransfer.dropEffect = 'copy';
            zone.classList.add('drag-over');
          });
          zone.addEventListener('dragleave', e => {
            zone.classList.remove('drag-over');
          });
          zone.addEventListener('drop', e => {
            e.preventDefault();
            zone.classList.remove('drag-over');
            const type = e.dataTransfer.getData('text/plain');
            const targetId = zone.dataset.dropTarget;
            if (type && targetId) {
              this.pushEvent('drop_on_node', { type: type, target_id: targetId });
            }
          });
        });
      }
    };
    """
  end
end
