defmodule Dala.Preview.Canvas do
  @moduledoc """
  Interactive drag-and-drop UI design canvas for Dala.

  A Phoenix LiveView that provides a visual design tool with:
  - Component palette (left sidebar) with icons and search
  - Design canvas with live phone-frame preview (center)
  - Property editor with grouped controls (right sidebar)
  - Code preview panel (bottom, collapsible)
  - Collapsible tree view with drag-to-reorder

  Uses the Dala UI tree map format internally with unique IDs for tracking.
  IDs are stripped during code generation.
  """

  use Phoenix.LiveView
  import Phoenix.HTML
  alias Dala.Preview.Codegen

  alias Dala.Ui.Component

  @components Component.all() |> Enum.map(fn {_name, comp} -> comp end)
  @container_types @components |> Enum.filter(&(&1.category == :container)) |> Enum.map(& &1.name)

  # Component icon mapping — emoji icons for visual palette
  @component_icons %{
    # Containers
    column: "⬜", row: "➡️", box: "📦", scroll: "📜", modal: "🪟",
    pressable: "👆", safe_area: "🛡️", card: "🃏", badge: "🔴",
    bottom_sheet: "📋", tooltip: "💬",
    # Leaf - text & input
    text: "📝", button: "🔘", text_field: "⌨️", search_bar: "🔍",
    toggle: "🔛", switch: "🔲", slider: "🎚️", checkbox: "☑️",
    radio: "🔘", chip: "🏷️", snackbar: "🍞",
    # Leaf - media
    icon: "⭐", image: "🖼️", video: "🎬", activity_indicator: "⏳",
    progress_bar: "📊", divider: "➖", spacer: "⬜",
    # Leaf - navigation
    app_bar: "📱", nav_bar: "📲", nav_drawer: "🗂️", nav_rail: "🚃",
    tab_bar: "📑", segmented_button: "📶", menu: "📋",
    # Leaf - other
    fab: "➕", icon_button: "🔳", webview: "🌐", camera_preview: "📷",
    native_view: "🔌", status_bar: "📶", refresh_control: "🔄",
    list: "📋", carousel: "🎠", date_picker: "📅", time_picker: "🕐"
  }

  # Grouped palette categories
  @palette_groups [
    {"Layout", [:column, :row, :box, :scroll, :safe_area, :card, :pressable, :modal, :bottom_sheet, :badge, :tooltip, :spacer, :divider]},
    {"Text & Input", [:text, :button, :text_field, :search_bar, :toggle, :switch, :slider, :checkbox, :radio, :chip]},
    {"Media", [:icon, :image, :video, :activity_indicator, :progress_bar, :webview, :camera_preview]},
    {"Navigation", [:app_bar, :nav_bar, :nav_drawer, :nav_rail, :tab_bar, :segmented_button, :fab, :icon_button]},
    {"Data & Lists", [:list, :carousel, :snackbar, :menu, :date_picker, :time_picker, :native_view, :status_bar, :refresh_control]}
  ]

  defp palette_groups, do: @palette_groups

  @component_specs %{
    column: [
      {:padding, :atom, nil},
      {:gap, :atom, nil},
      {:background, :atom, nil},
      {:border_color, :atom, nil},
      {:border_width, :integer, nil},
      {:corner_radius, :integer, nil},
      {:fill_width, :boolean, false},
      {:fill_height, :boolean, false},
      {:width, :integer, nil},
      {:height, :integer, nil},
      {:scrollable, :boolean, false},
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
      {:fill_height, :boolean, false},
      {:width, :integer, nil},
      {:height, :integer, nil},
      {:scrollable, :boolean, false},
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
    ],
    card: [
      {:variant, :atom, :elevated},
      {:elevation, :float, 1.0},
      {:corner_radius, :integer, 12},
      {:padding, :atom, nil},
      {:background, :atom, nil},
      {:fill_width, :boolean, false},
      {:on_tap, :event, nil}
    ],
    badge: [
      {:count, :integer, 0},
      {:color, :atom, nil},
      {:text_color, :atom, nil},
      {:visible, :boolean, true}
    ],
    bottom_sheet: [
      {:visible, :boolean, false},
      {:height, :integer, nil},
      {:corner_radius, :integer, 16},
      {:background, :atom, nil},
      {:on_dismiss, :event, nil}
    ],
    tooltip: [
      {:text, :string, ""},
      {:position, :atom, :top},
      {:visible, :boolean, false}
    ],
    checkbox: [
      {:value, :boolean, false},
      {:label, :string, ""},
      {:on_change, :event, nil},
      {:disabled, :boolean, false}
    ],
    radio: [
      {:selected, :boolean, false},
      {:label, :string, ""},
      {:group, :string, ""},
      {:on_select, :event, nil}
    ],
    chip: [
      {:label, :string, "Chip"},
      {:variant, :atom, :filter},
      {:selected, :boolean, false},
      {:on_tap, :event, nil},
      {:on_remove, :event, nil}
    ],
    snackbar: [
      {:message, :string, ""},
      {:action_label, :string, nil},
      {:visible, :boolean, false},
      {:on_action, :event, nil}
    ],
    fab: [
      {:icon, :atom, :add},
      {:text, :string, nil},
      {:on_tap, :event, nil},
      {:background, :atom, nil}
    ],
    icon_button: [
      {:icon, :atom, :star},
      {:on_tap, :event, nil},
      {:selected, :boolean, false},
      {:disabled, :boolean, false}
    ],
    segmented_button: [
      {:selected, :string, ""},
      {:on_select, :event, nil}
    ],
    app_bar: [
      {:title, :string, "App"},
      {:leading_icon, :atom, nil},
      {:on_leading, :event, nil},
      {:background, :atom, nil}
    ],
    nav_bar: [
      {:active, :string, ""},
      {:on_select, :event, nil},
      {:background, :atom, nil}
    ],
    nav_drawer: [
      {:visible, :boolean, false},
      {:active, :string, ""},
      {:on_select, :event, nil},
      {:on_dismiss, :event, nil}
    ],
    nav_rail: [
      {:active, :string, ""},
      {:on_select, :event, nil}
    ],
    menu: [
      {:visible, :boolean, false},
      {:on_select, :event, nil}
    ],
    date_picker: [
      {:visible, :boolean, false},
      {:selected_date, :string, ""},
      {:on_select, :event, nil}
    ],
    time_picker: [
      {:visible, :boolean, false},
      {:selected_time, :string, ""},
      {:on_select, :event, nil}
    ],
    search_bar: [
      {:placeholder, :string, "Search..."},
      {:value, :string, ""},
      {:on_change, :event, nil},
      {:on_submit, :event, nil}
    ],
    carousel: [
      {:loop, :boolean, false},
      {:autoplay, :boolean, false},
      {:on_page_change, :event, nil}
    ]
  }

  # ── LiveView callbacks ──────────────────────────────────────────────────────

  @impl true
  def mount(_params, session, socket) do
    initial_tree = session["initial_tree"]
    initial_module = session["initial_module"] || "MyApp.HomeScreen"

    {:ok,
     assign(socket,
       tree: initial_tree || empty_root(),
       selected_id: nil,
       code_style: :dsl,
       module_name: initial_module,
       show_code: true,
       drag_type: nil,
       id_counter: 1,
       collapsed_nodes: MapSet.new(),
       palette_search: "",
      copied: false
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="design-canvas" class="design-canvas-root" phx-hook="DesignCanvas">
      <style><%= raw(canvas_css()) %></style>
      <.header_bar show_code={@show_code} module_name={@module_name} />
      <div class="canvas-body">
        <.palette search={@palette_search} />
        <.design_canvas tree={@tree} selected_id={@selected_id} collapsed={@collapsed_nodes} />
        <.property_editor tree={@tree} selected_id={@selected_id} />
      </div>
      <%= if @show_code do %>
        <.code_panel tree={@tree} code_style={@code_style} module_name={@module_name} copied={@copied} />
      <% end %>
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
        <span class="canvas-logo">◇</span>
        <span class="canvas-title">Dala Designer</span>
      </div>
      <div class="canvas-header-center">
        <form phx-submit="set_module_name" phx-change="set_module_name" class="module-name-form">
          <input
            type="text"
            name="value"
            class="module-name-input"
            value={@module_name}
            placeholder="MyApp.Screen"
          />
        </form>
      </div>
      <div class="canvas-header-right">
        <span class="code-style-label">DSL</span>
        <button class="header-btn" phx-click="toggle_code">
          <%= if @show_code, do: "◉ Code", else: "○ Code" %>
        </button>
        <button class="header-btn danger" phx-click="clear_canvas">✕ Clear</button>
      </div>
    </div>
    """
  end

  # ── Component: Palette ───────────────────────────────────────────────────────

  attr(:search, :string, default: "")

  def palette(assigns) do
    ~H"""
    <div class="palette">
      <div class="palette-search">
        <input
          type="text"
          class="palette-search-input"
          placeholder="Search components..."
          value={@search}
          phx-change="palette_search"
          phx-debounce="200"
        />
      </div>
      <%= for {group_name, type_list} <- palette_groups() do %>
        <% items = Enum.filter(type_list, fn t ->
          label = format_type(t)
          search = String.downcase(@search)
          search == "" or String.contains?(String.downcase(label), search)
        end) %>
        <%= if items != [] do %>
          <div class="palette-section">
            <div class="palette-section-title"><%= group_name %></div>
            <div class="palette-items">
              <%= for type <- items do %>
                <% icon = Map.get(@component_icons, type, "•") %>
                <% is_container = type in @container_types %>
                <div
                  class={"palette-item #{if is_container, do: "palette-item--container", else: "palette-item--leaf"}"}
                  draggable="true"
                  phx-click="add_node"
                  phx-value-type={to_string(type)}
                  data-drag-type={to_string(type)}
                  title={format_type(type)}
                >
                  <span class="palette-icon"><%= icon %></span>
                  <span class="palette-label"><%= format_type(type) %></span>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end

  # ── Component: Design Canvas ─────────────────────────────────────────────────

  attr(:tree, :map, required: true)
  attr(:selected_id, :any, default: nil)
  attr(:collapsed, :any, default: nil)

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
        <div class="tree-view-header">Component Tree</div>
        <div class="tree-view-content">
          <.tree_node node={@tree} selected_id={@selected_id} depth={0} collapsed={@collapsed} />
        </div>
      </div>
    </div>
    """
  end

  # ── Component: Tree Node ─────────────────────────────────────────────────────

  attr(:node, :map, required: true)
  attr(:selected_id, :any, default: nil)
  attr(:depth, :integer, default: 0)
  attr(:collapsed, :any, default: nil)

  def tree_node(assigns) do
    collapsed = assigns.collapsed || MapSet.new()
    is_collapsed = MapSet.member?(collapsed, assigns.node.id)

    assigns =
      assign(assigns,
        is_collapsed: is_collapsed,
        icon: Map.get(@component_icons, assigns.node.type, "•")
      )

    ~H"""
    <div
      class={"tree-node #{tree_node_classes(@node, @selected_id)}"}
    >
      <div
        class="tree-node-header"
        style={"padding-left: #{@depth * 14 + 6}px"}
        phx-click="select_node"
        phx-value-id={@node.id}
      >
        <%= if container_type?(@node.type) do %>
          <span
            class={"tree-node-toggle #{if @is_collapsed, do: "tree-node-toggle--collapsed"}"}
            phx-click="toggle_node"
            phx-value-id={@node.id}
          >▾</span>
        <% else %>
          <span class="tree-node-toggle tree-node-toggle--leaf">•</span>
        <% end %>
        <span class="tree-node-icon"><%= @icon %></span>
        <span class="tree-node-type"><%= format_type(@node.type) %></span>
        <%= if @node.props[:text] do %>
          <span class="tree-node-text">"<%= truncate(@node.props[:text], 18) %>"</span>
        <% end %>
        <%= if container_type?(@node.type) do %>
          <span class="tree-node-badge"><%= length(@node.children || []) %></span>
        <% end %>
      </div>
      <%= if container_type?(@node.type) and has_children?(@node) and not @is_collapsed do %>
        <div
          class="tree-node-children drop-zone"
          data-drop-target={@node.id}
        >
          <%= for child <- @node.children do %>
            <.tree_node node={child} selected_id={@selected_id} depth={@depth + 1} collapsed={@collapsed} />
          <% end %>
        </div>
      <% end %>
      <%= if container_type?(@node.type) and (not has_children?(@node) or @is_collapsed) do %>
        <div
          class="tree-node-children tree-node-empty drop-zone"
          data-drop-target={@node.id}
          style={if @is_collapsed, do: "display: none;", else: ""}
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
  attr(:copied, :boolean, default: false)

  def code_panel(assigns) do
    ~H"""
    <div class="code-panel">
      <div class="code-panel-header">
        <span>◇ Generated Code</span>
        <button class="code-copy-btn" phx-click="copy_code">
          <%= if @copied, do: "✓ Copied!", else: "⧉ Copy" %>
        </button>
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

  def handle_event("toggle_node", %{"id" => id}, socket) do
    collapsed = socket.assigns.collapsed_nodes
    updated = if MapSet.member?(collapsed, id), do: MapSet.delete(collapsed, id), else: MapSet.put(collapsed, id)
    {:noreply, assign(socket, collapsed_nodes: updated)}
  end

  def handle_event("palette_search", %{"value" => value}, socket) do
    {:noreply, assign(socket, palette_search: value || "")}
  end

  def handle_event("copy_code", _params, socket) do
    {:noreply, assign(socket, copied: true)}
  end

  # ── Test helpers ────────────────────────────────────────────────────────────

  @doc false
  def call_private(:empty_root, []), do: empty_root()
  def call_private(:make_node, [type, counter]), do: make_node(type, counter)
  def call_private(:add_node_to_tree, [tree, target_id, new_node]), do: add_node_to_tree(tree, target_id, new_node)
  def call_private(:remove_node_from_tree, [tree, node_id]), do: remove_node_from_tree(tree, node_id)
  def call_private(:update_node_in_tree, [tree, node_id, update_fn]), do: update_node_in_tree(tree, node_id, update_fn)
  def call_private(:find_node, [tree, node_id]), do: find_node(tree, node_id)
  def call_private(:strip_ids, [tree]), do: strip_ids(tree)
  def call_private(:default_props, [type]), do: default_props(type)
  def call_private(:parse_prop_value, [value_str, spec]), do: parse_prop_value(value_str, spec)
  def call_private(:container_type?, [type]), do: container_type?(type)
  def call_private(:has_children?, [node]), do: has_children?(node)
  def call_private(:format_type, [type]), do: format_type(type)
  def call_private(:truncate, [text, max_len]), do: truncate(text, max_len)
  def call_private(:prop_defs_for, [type]), do: prop_defs_for(type)

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
  defp default_props(:card), do: %{variant: :elevated, elevation: 1.0, corner_radius: 12}
  defp default_props(:badge), do: %{count: 3}
  defp default_props(:bottom_sheet), do: %{}
  defp default_props(:tooltip), do: %{text: "Tooltip"}
  defp default_props(:checkbox), do: %{label: "Checkbox", value: false}
  defp default_props(:radio), do: %{label: "Radio", selected: false}
  defp default_props(:chip), do: %{label: "Chip", variant: :filter}
  defp default_props(:snackbar), do: %{message: "Notification", visible: false}
  defp default_props(:fab), do: %{icon: :add}
  defp default_props(:icon_button), do: %{icon: :star}
  defp default_props(:segmented_button), do: %{selected: ""}
  defp default_props(:app_bar), do: %{title: "My App"}
  defp default_props(:nav_bar), do: %{active: "home"}
  defp default_props(:nav_drawer), do: %{}
  defp default_props(:nav_rail), do: %{}
  defp default_props(:menu), do: %{}
  defp default_props(:date_picker), do: %{}
  defp default_props(:time_picker), do: %{}
  defp default_props(:search_bar), do: %{placeholder: "Search..."}
  defp default_props(:carousel), do: %{}
  defp default_props(_), do: %{}

  defp container_type?(type), do: type in @container_types
  defp has_children?(node), do: node[:children] != nil and node.children != []

  # ── Rendering helpers ────────────────────────────────────────────────────────

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
      _ ->
        case Float.parse(str) do
          {f, ""} -> f
          _ -> str
        end
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

  defp render_preview_component(:card, props, children) do
    style = build_preview_style(props) <> " background: #fff; box-shadow: 0 1px 3px rgba(0,0,0,0.12), 0 1px 2px rgba(0,0,0,0.08);"
    "<div class=\"dala-card\" style=\"#{style}\">#{render_preview_children(children)}</div>"
  end

  defp render_preview_component(:checkbox, props, _children) do
    label = escape_html(props[:label] || "")
    checked = props[:value] == true
    mark = if checked, do: "☑", else: "☐"
    "<div class=\"dala-checkbox\" style=\"display: flex; align-items: center; gap: 6px; padding: 4px 0;\"><span>#{mark}</span><span>#{label}</span></div>"
  end

  defp render_preview_component(:radio, props, _children) do
    label = escape_html(props[:label] || "")
    selected = props[:selected] == true
    mark = if selected, do: "◉", else: "○"
    "<div class=\"dala-radio\" style=\"display: flex; align-items: center; gap: 6px; padding: 4px 0;\"><span>#{mark}</span><span>#{label}</span></div>"
  end

  defp render_preview_component(:chip, props, _children) do
    label = escape_html(props[:label] || "Chip")
    selected = props[:selected] == true
    bg = if selected, do: "background: var(--accent); color: white;", else: "background: #f1f5f9; color: #475569;"
    "<span class=\"dala-chip\" style=\"#{bg} padding: 4px 12px; border-radius: 999px; font-size: 12px; display: inline-block;\">#{label}</span>"
  end

  defp render_preview_component(:fab, props, _children) do
    icon = props[:icon] || "add"
    text = props[:text]
    content = if text, do: "#{icon} #{text}", else: "#{icon}"
    "<div class=\"dala-fab\" style=\"width: 48px; height: 48px; border-radius: 16px; background: linear-gradient(135deg, var(--accent), #818cf8); color: white; display: flex; align-items: center; justify-content: center; font-size: 18px; box-shadow: 0 4px 12px var(--accent-glow);\">#{content}</div>"
  end

  defp render_preview_component(:icon_button, props, _children) do
    icon = props[:icon] || "star"
    selected = props[:selected] == true
    bg = if selected, do: "background: var(--accent-glow);", else: ""
    "<div class=\"dala-icon-button\" style=\"#{bg} width: 36px; height: 36px; border-radius: 50%; display: flex; align-items: center; justify-content: center; cursor: pointer;\">#{icon}</div>"
  end

  defp render_preview_component(:app_bar, props, _children) do
    title = escape_html(props[:title] || "App")
    "<div class=\"dala-app-bar\" style=\"background: linear-gradient(135deg, var(--accent), #818cf8); color: white; padding: 12px 16px; font-size: 16px; font-weight: 600; display: flex; align-items: center; gap: 12px;\"><span>☰</span><span>#{title}</span></div>"
  end

  defp render_preview_component(:search_bar, props, _children) do
    placeholder = escape_html(props[:placeholder] || "Search...")
    "<div class=\"dala-search-bar\" style=\"background: #f1f5f9; border-radius: 10px; padding: 8px 12px; color: #94a3b8; font-size: 13px; display: flex; align-items: center; gap: 8px;\"><span>🔍</span><span>#{placeholder}</span></div>"
  end

  defp render_preview_component(:snackbar, props, _children) do
    if props[:visible] == true do
      message = escape_html(props[:message] || "")
      action = props[:action_label] || ""
      action_html = if action != "", do: "<span style='color: var(--accent-hover); font-weight: 600; margin-left: 12px;'>#{escape_html(action)}</span>", else: ""
      "<div class=\"dala-snackbar\" style=\"background: #323232; color: white; padding: 10px 14px; border-radius: 6px; font-size: 13px; display: flex; align-items: center;\">#{message}#{action_html}</div>"
    else
      ""
    end
  end

  defp render_preview_component(:carousel, _props, _children) do
    "<div class=\"dala-carousel\" style=\"background: #f8fafc; border-radius: 8px; padding: 20px; text-align: center; color: #94a3b8; font-size: 13px;\">🎠 Carousel</div>"
  end

  defp render_preview_component(:badge, props, children) do
    if props[:visible] != false do
      count = props[:count] || 0
      "<div class=\"dala-badge\" style=\"position: relative; display: inline-flex;\">#{render_preview_children(children)}<span style=\"position: absolute; top: -4px; right: -4px; background: #ef4444; color: white; font-size: 9px; min-width: 16px; height: 16px; border-radius: 8px; display: flex; align-items: center; justify-content: center; font-weight: 700;\">#{count}</span></div>"
    else
      "<div class=\"dala-badge\">#{render_preview_children(children)}</div>"
    end
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
      :height,
      :fill_width,
      :fill_height
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
  defp preview_css_property(:fill_width), do: "width"
  defp preview_css_property(:fill_height), do: "height"
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
  defp preview_css_value(true), do: "100%"
  defp preview_css_value(false), do: "auto"
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
  defp preview_color(color), do: "#{color}"

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
    /* ── Design Tool CSS ─────────────────────────────────────────────────────── */
    :root {
      --bg-primary: #0f0f1a;
      --bg-secondary: #1a1a2e;
      --bg-tertiary: #252540;
      --accent: #6366f1;
      --accent-hover: #818cf8;
      --accent-glow: rgba(99, 102, 241, 0.15);
      --accent-glow-strong: rgba(99, 102, 241, 0.3);
      --text-primary: #f1f5f9;
      --text-secondary: #94a3b8;
      --text-muted: #64748b;
      --border: rgba(255, 255, 255, 0.06);
      --border-light: rgba(255, 255, 255, 0.1);
      --success: #34d399;
      --danger: #f87171;
      --warning: #fbbf24;
      --shadow-sm: 0 1px 3px rgba(0, 0, 0, 0.3);
      --shadow-md: 0 4px 12px rgba(0, 0, 0, 0.4);
      --shadow-lg: 0 8px 32px rgba(0, 0, 0, 0.5);
      --shadow-glow: 0 0 20px rgba(99, 102, 241, 0.15);
      --radius-sm: 6px;
      --radius-md: 8px;
      --radius-lg: 12px;
      --radius-xl: 16px;
      --radius-pill: 9999px;
      --transition-fast: 0.15s ease;
      --transition-normal: 0.2s ease;
      --transition-slow: 0.3s ease;
    }

    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    /* ── Scrollbar styling ───────────────────────────────────────────────────── */
    ::-webkit-scrollbar { width: 6px; height: 6px; }
    ::-webkit-scrollbar-track { background: transparent; }
    ::-webkit-scrollbar-thumb {
      background: var(--bg-tertiary);
      border-radius: var(--radius-pill);
      transition: background var(--transition-fast);
    }
    ::-webkit-scrollbar-thumb:hover { background: var(--text-muted); }

    /* ── Root layout ─────────────────────────────────────────────────────────── */
    .design-canvas-root {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
      display: flex;
      flex-direction: column;
      height: 100vh;
      background: var(--bg-primary);
      color: var(--text-primary);
      overflow: hidden;
    }

    /* ── Header ──────────────────────────────────────────────────────────────── */
    .canvas-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 10px 20px;
      background: rgba(26, 26, 46, 0.8);
      backdrop-filter: blur(12px);
      -webkit-backdrop-filter: blur(12px);
      border-bottom: 1px solid var(--border);
      position: relative;
      z-index: 10;
    }
    .canvas-header::after {
      content: "";
      position: absolute;
      bottom: -1px;
      left: 0;
      right: 0;
      height: 1px;
      background: linear-gradient(90deg, transparent, var(--accent-glow), transparent);
    }
    .canvas-header-left {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .canvas-logo {
      font-size: 22px;
      background: linear-gradient(135deg, var(--accent), #a78bfa);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
      filter: drop-shadow(0 0 8px var(--accent-glow));
    }
    .canvas-title {
      font-size: 14px;
      font-weight: 600;
      color: var(--text-primary);
      letter-spacing: 0.3px;
    }
    .canvas-header-center {
      display: flex;
      align-items: center;
      flex: 1;
      justify-content: center;
    }
    .canvas-header-right {
      display: flex;
      align-items: center;
      gap: 10px;
    }
    .module-name-form {
      display: flex;
      flex: 1;
      max-width: 340px;
    }

    .code-style-label {
      padding: 5px 14px;
      background: linear-gradient(135deg, var(--accent), #818cf8);
      color: white;
      border-radius: var(--radius-pill);
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 0.5px;
      text-transform: uppercase;
      box-shadow: 0 2px 8px var(--accent-glow);
    }

    .header-btn {
      padding: 5px 14px;
      border: 1px solid var(--border-light);
      background: var(--bg-tertiary);
      color: var(--text-secondary);
      border-radius: var(--radius-sm);
      cursor: pointer;
      font-size: 12px;
      font-weight: 500;
      transition: all var(--transition-normal);
    }
    .header-btn:hover {
      background: var(--border-light);
      color: var(--text-primary);
      border-color: var(--text-muted);
    }
    .header-btn:active {
      transform: scale(0.97);
    }
    .header-btn.danger {
      border-color: rgba(248, 113, 113, 0.3);
      color: var(--danger);
    }
    .header-btn.danger:hover {
      background: rgba(248, 113, 113, 0.15);
      border-color: var(--danger);
    }

    /* ── Body layout ─────────────────────────────────────────────────────────── */
    .canvas-body {
      display: flex;
      flex: 1;
      overflow: hidden;
    }

    /* ── Palette (left sidebar) ──────────────────────────────────────────────── */
    .palette {
      width: 220px;
      background: var(--bg-secondary);
      border-right: 1px solid var(--border);
      overflow-y: auto;
      padding: 12px 8px;
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .palette-section {
      margin-bottom: 8px;
    }
    .palette-section-title {
      font-size: 10px;
      text-transform: uppercase;
      letter-spacing: 1.2px;
      color: var(--text-muted);
      margin-bottom: 6px;
      padding: 0 8px;
      font-weight: 600;
    }
    .palette-items {
      display: flex;
      flex-direction: column;
      gap: 1px;
    }
    .palette-item {
      display: flex;
      align-items: center;
      gap: 8px;
      padding: 7px 10px;
      border-radius: var(--radius-sm);
      cursor: pointer;
      font-size: 12px;
      font-weight: 500;
      transition: all var(--transition-normal);
      user-select: none;
      position: relative;
      overflow: hidden;
    }
    .palette-item::before {
      content: "";
      position: absolute;
      inset: 0;
      background: linear-gradient(135deg, var(--accent-glow), transparent);
      opacity: 0;
      transition: opacity var(--transition-normal);
    }
    .palette-item:hover {
      background: var(--bg-tertiary);
      color: var(--text-primary);
    }
    .palette-item:hover::before {
      opacity: 1;
    }
    .palette-item:active {
      transform: scale(0.98);
    }
    .palette-item--container .palette-icon {
      color: var(--accent);
      filter: drop-shadow(0 0 4px var(--accent-glow));
    }
    .palette-item--leaf .palette-icon {
      color: var(--success);
      filter: drop-shadow(0 0 4px rgba(52, 211, 153, 0.2));
    }
    .palette-icon {
      font-size: 14px;
      width: 18px;
      text-align: center;
      position: relative;
      z-index: 1;
    }
    .palette-search {
      padding: 0 4px 8px 4px;
      border-bottom: 1px solid var(--border);
      margin-bottom: 8px;
    }
    .palette-search-input {
      width: 100%;
      background: var(--bg-tertiary);
      border: 1px solid var(--border);
      color: var(--text-primary);
      padding: 6px 10px;
      border-radius: var(--radius-sm);
      font-size: 11px;
      transition: all var(--transition-normal);
      font-family: inherit;
    }
    .palette-search-input:focus {
      outline: none;
      border-color: var(--accent);
      box-shadow: 0 0 0 3px var(--accent-glow);
    }
    .palette-search-input::placeholder {
      color: var(--text-muted);
    }
    .palette-label {
      color: var(--text-secondary);
      position: relative;
      z-index: 1;
      transition: color var(--transition-normal);
    }
    .palette-item:hover .palette-label {
      color: var(--text-primary);
    }

    /* ── Design Canvas (center) ──────────────────────────────────────────────── */
    .design-canvas {
      flex: 1;
      display: flex;
      overflow: hidden;
      background: var(--bg-primary);
      background-image:
        radial-gradient(ellipse at 50% 0%, rgba(99, 102, 241, 0.05) 0%, transparent 60%);
    }
    .canvas-phone-frame {
      flex: 1;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 24px;
      gap: 0;
    }
    .canvas-phone-notch {
      width: 130px;
      height: 28px;
      background: #1a1a1a;
      border-radius: 0 0 16px 16px;
      margin-bottom: -1px;
      position: relative;
      z-index: 1;
      box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
    }
    .canvas-phone-notch::after {
      content: "";
      position: absolute;
      top: 8px;
      left: 50%;
      transform: translateX(-50%);
      width: 50px;
      height: 4px;
      background: #333;
      border-radius: 2px;
    }
    .canvas-phone-screen {
      width: 320px;
      height: 580px;
      background: #ffffff;
      border-radius: 0 0 20px 20px;
      overflow-y: auto;
      overflow-x: hidden;
      box-shadow:
        0 0 0 2px rgba(255, 255, 255, 0.05),
        0 8px 40px rgba(0, 0, 0, 0.5),
        0 0 80px rgba(99, 102, 241, 0.06);
      position: relative;
    }
    .canvas-phone-screen::-webkit-scrollbar { width: 4px; }
    .canvas-phone-screen::-webkit-scrollbar-track { background: transparent; }
    .canvas-phone-screen::-webkit-scrollbar-thumb { background: rgba(0,0,0,0.15); border-radius: 2px; }

    .live-preview {
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
      font-size: 14px;
      color: #1e293b;
      padding: 0;
      min-height: 100%;
      background: #ffffff;
    }

    /* ── Tree View (right of phone) ──────────────────────────────────────────── */
    .canvas-tree-view {
      width: 240px;
      background: var(--bg-secondary);
      border-left: 1px solid var(--border);
      display: flex;
      flex-direction: column;
      overflow: hidden;
    }
    .tree-view-header {
      padding: 10px 14px;
      font-size: 10px;
      text-transform: uppercase;
      letter-spacing: 1.2px;
      color: var(--text-muted);
      border-bottom: 1px solid var(--border);
      font-weight: 600;
      background: rgba(26, 26, 46, 0.5);
    }
    .tree-view-content {
      overflow-y: auto;
      flex: 1;
      padding: 6px 4px;
    }

    .tree-node {
      cursor: pointer;
      border-radius: var(--radius-sm);
      margin: 1px 0;
      transition: all var(--transition-normal);
      position: relative;
    }
    .tree-node:hover {
      background: var(--accent-glow);
    }
    .tree-node--selected {
      background: var(--accent-glow);
      box-shadow: inset 2px 0 0 var(--accent);
    }
    .tree-node-header {
      display: flex;
      align-items: center;
      gap: 6px;
      padding: 5px 8px;
      font-size: 12px;
      min-height: 30px;
      border-radius: var(--radius-sm);
      transition: background var(--transition-fast);
    }
    .tree-node-toggle {
      font-size: 10px;
      color: var(--text-muted);
      width: 14px;
      text-align: center;
      cursor: pointer;
      transition: transform var(--transition-normal);
      flex-shrink: 0;
    }
    .tree-node-toggle--collapsed {
      transform: rotate(-90deg);
    }
    .tree-node-toggle--leaf {
      color: var(--text-muted);
      opacity: 0.4;
    }
    .tree-node-icon {
      font-size: 12px;
      flex-shrink: 0;
    }
    .tree-node-type {
      font-weight: 600;
      color: var(--accent-hover);
      font-size: 11px;
    }
    .tree-node-text {
      color: var(--text-muted);
      font-style: italic;
      font-size: 11px;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
      max-width: 100px;
    }
    .tree-node-badge {
      font-size: 9px;
      background: var(--bg-tertiary);
      color: var(--text-muted);
      padding: 2px 6px;
      border-radius: var(--radius-pill);
      font-weight: 500;
      margin-left: auto;
    }
    .tree-node-children {
      border-left: 1px solid var(--border);
      margin-left: 14px;
      padding-left: 2px;
    }
    .tree-node-empty {
      padding: 8px 12px;
      color: var(--text-muted);
      font-size: 11px;
      font-style: italic;
      border: 1px dashed var(--border);
      border-radius: var(--radius-sm);
      margin: 4px 8px;
      text-align: center;
      transition: all var(--transition-normal);
    }
    .drop-zone.drag-over {
      background: var(--accent-glow);
      border-color: var(--accent);
      box-shadow: 0 0 12px var(--accent-glow);
    }

    /* ── Property Editor (right sidebar) ─────────────────────────────────────── */
    .property-editor {
      width: 260px;
      background: var(--bg-secondary);
      border-left: 1px solid var(--border);
      display: flex;
      flex-direction: column;
      overflow: hidden;
    }
    .property-editor-header {
      padding: 10px 14px;
      font-size: 10px;
      text-transform: uppercase;
      letter-spacing: 1.2px;
      color: var(--text-muted);
      border-bottom: 1px solid var(--border);
      font-weight: 600;
      background: rgba(26, 26, 46, 0.5);
    }
    .property-editor-empty {
      padding: 24px 16px;
      color: var(--text-muted);
      font-size: 12px;
      text-align: center;
      line-height: 1.5;
    }

    .prop-editor {
      padding: 12px;
      overflow-y: auto;
      flex: 1;
    }
    .prop-editor-type {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 14px;
      padding-bottom: 10px;
      border-bottom: 1px solid var(--border);
    }
    .prop-type-badge {
      background: linear-gradient(135deg, var(--accent-glow), rgba(99, 102, 241, 0.08));
      color: var(--accent-hover);
      padding: 3px 10px;
      border-radius: var(--radius-pill);
      font-size: 11px;
      font-weight: 700;
      letter-spacing: 0.3px;
      border: 1px solid rgba(99, 102, 241, 0.2);
    }
    .prop-delete-btn {
      background: transparent;
      border: 1px solid rgba(248, 113, 113, 0.25);
      color: var(--danger);
      padding: 3px 10px;
      border-radius: var(--radius-sm);
      cursor: pointer;
      font-size: 11px;
      font-weight: 500;
      transition: all var(--transition-normal);
    }
    .prop-delete-btn:hover {
      background: rgba(248, 113, 113, 0.12);
      border-color: var(--danger);
    }

    .prop-editor-fields {
      display: flex;
      flex-direction: column;
      gap: 10px;
    }
    .prop-field {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }
    .prop-field form {
      display: flex;
    }
    .prop-label {
      font-size: 10px;
      text-transform: uppercase;
      letter-spacing: 0.8px;
      color: var(--text-muted);
      font-weight: 600;
    }
    .prop-input {
      background: var(--bg-tertiary);
      border: 1px solid var(--border);
      color: var(--text-primary);
      padding: 6px 10px;
      border-radius: var(--radius-sm);
      font-size: 12px;
      width: 100%;
      transition: all var(--transition-normal);
      font-family: inherit;
    }
    .prop-input:focus {
      outline: none;
      border-color: var(--accent);
      box-shadow: 0 0 0 3px var(--accent-glow);
    }
    .prop-input::placeholder {
      color: var(--text-muted);
    }
    .prop-input--number {
      width: 90px;
    }
    .prop-input--event {
      font-family: "JetBrains Mono", "Fira Code", "SF Mono", monospace;
      font-size: 11px;
    }
    .prop-checkbox {
      width: 16px;
      height: 16px;
      accent-color: var(--accent);
      cursor: pointer;
      border-radius: 3px;
    }

    /* ── Code Panel (bottom) ─────────────────────────────────────────────────── */
    .code-panel {
      background: #0d1117;
      border-top: 1px solid var(--border);
      max-height: 280px;
      display: flex;
      flex-direction: column;
    }
    .code-panel-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 8px 14px;
      background: #161b22;
      border-bottom: 1px solid var(--border);
    }
    .code-panel-header span {
      font-size: 10px;
      color: var(--text-muted);
      text-transform: uppercase;
      letter-spacing: 1.2px;
      font-weight: 600;
    }
    .code-copy-btn {
      background: transparent;
      border: 1px solid var(--border-light);
      color: var(--text-secondary);
      padding: 3px 12px;
      border-radius: var(--radius-sm);
      cursor: pointer;
      font-size: 11px;
      font-weight: 500;
      transition: all var(--transition-normal);
    }
    .code-copy-btn:hover {
      background: var(--bg-tertiary);
      color: var(--text-primary);
      border-color: var(--text-muted);
    }
    .code-panel-content {
      flex: 1;
      overflow: auto;
      padding: 14px 16px;
      margin: 0;
      font-family: "JetBrains Mono", "Fira Code", "SF Mono", "Cascadia Code", monospace;
      font-size: 12px;
      line-height: 1.6;
      color: #c9d1d9;
      white-space: pre;
      background: linear-gradient(180deg, #0d1117 0%, #0a0e14 100%);
    }

    /* ── Canvas Footer ───────────────────────────────────────────────────────── */
    .canvas-footer {
      display: flex;
      align-items: center;
      gap: 10px;
      padding: 8px 20px;
      background: var(--bg-secondary);
      border-top: 1px solid var(--border);
    }
    .module-name-label {
      font-size: 10px;
      color: var(--text-muted);
      text-transform: uppercase;
      letter-spacing: 1px;
      font-weight: 600;
      white-space: nowrap;
    }
    .module-name-input {
      background: var(--bg-tertiary);
      border: 1px solid var(--border);
      color: var(--text-primary);
      padding: 5px 12px;
      border-radius: var(--radius-pill);
      font-size: 12px;
      flex: 1;
      max-width: 320px;
      transition: all var(--transition-normal);
      font-family: inherit;
    }
    .module-name-input:focus {
      outline: none;
      border-color: var(--accent);
      box-shadow: 0 0 0 3px var(--accent-glow);
    }
    .module-name-input::placeholder {
      color: var(--text-muted);
    }

    /* ── Dala preview styles (inside phone frame) ────────────────────────────── */
    .live-preview .dala-column {
      display: flex;
      flex-direction: column;
    }
    .live-preview .dala-row {
      display: flex;
      flex-direction: row;
      align-items: center;
    }
    .live-preview .dala-text {
      padding: 2px 0;
      color: #1e293b;
      line-height: 1.4;
    }
    .live-preview .dala-button {
      background: linear-gradient(135deg, var(--accent), #818cf8);
      color: white;
      border: none;
      border-radius: var(--radius-md);
      padding: 8px 18px;
      font-size: 14px;
      font-weight: 600;
      cursor: pointer;
      transition: all var(--transition-normal);
      box-shadow: 0 2px 8px var(--accent-glow);
    }
    .live-preview .dala-button:hover {
      box-shadow: 0 4px 16px var(--accent-glow-strong);
      transform: translateY(-1px);
    }
    .live-preview .dala-box {
      display: flex;
    }
    .live-preview .dala-spacer { flex: 1; }
    .live-preview .dala-divider {
      border: none;
      border-top: 1px solid #e2e8f0;
      margin: 8px 0;
    }
    .live-preview .dala-icon {
      font-size: 18px;
      line-height: 1;
    }
    .live-preview .dala-toggle {
      width: 44px;
      height: 24px;
      background: #cbd5e1;
      border-radius: 12px;
      position: relative;
      cursor: pointer;
      transition: background var(--transition-normal);
    }
    .live-preview .dala-toggle::after {
      content: "";
      position: absolute;
      top: 2px;
      left: 2px;
      width: 20px;
      height: 20px;
      background: white;
      border-radius: 50%;
      transition: transform var(--transition-normal);
      box-shadow: var(--shadow-sm);
    }
    .live-preview .dala-switch {
      display: inline-block;
    }
    .live-preview .dala-slider {
      width: 100%;
      accent-color: var(--accent);
    }
    .live-preview .dala-progress-bar {
      background: linear-gradient(90deg, var(--accent), #818cf8);
      height: 4px;
      border-radius: 2px;
    }
    .live-preview .dala-text-field {
      border: 1px solid #e2e8f0;
      border-radius: var(--radius-md);
      padding: 8px 12px;
      font-size: 14px;
      width: 100%;
      transition: all var(--transition-normal);
      background: #f8fafc;
    }
    .live-preview .dala-text-field:focus {
      outline: none;
      border-color: var(--accent);
      box-shadow: 0 0 0 3px var(--accent-glow);
      background: white;
    }
    .live-preview .dala-list {
      display: flex;
      flex-direction: column;
    }
    .live-preview .dala-list-item {
      padding: 10px 12px;
      border-bottom: 1px solid #f1f5f9;
      cursor: pointer;
      transition: background var(--transition-fast);
    }
    .live-preview .dala-list-item:hover {
      background: #f8fafc;
    }
    .live-preview .dala-unknown {
      padding: 4px;
      color: var(--text-muted);
    }
    """
  end

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
