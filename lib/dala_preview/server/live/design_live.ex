defmodule DalaPreview.Server.DesignLive do
  use Phoenix.LiveView, layout: {DalaPreview.Server.Layouts, :app}
  alias DalaPreview.Server.Design

  @component_types [:column, :row, :text, :button]

  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:design, Design.new())
      |> assign(:component_types, @component_types)
      |> assign(:selected_node, nil)
      |> assign(:active_tab, "components")
      |> assign(:export_format, "sigil")
      |> assign(:generated_code, "")
      |> assign(:zoom, 100)
      |> assign(:grid_visible, true)
      |> assign(:snap_to_grid, true)
      |> assign(:grid_size, 20)

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="design-editor">
      <!-- Left Panel -->
      <div class="left-panel">
        <div class="tabs">
          <button class={@active_tab == "components" && "active"} phx-click="select_tab" phx-value-tab="components">
            Components
          </button>
          <button class={@active_tab == "properties" && "active"} phx-click="select_tab" phx-value-tab="properties">
            Properties
          </button>
          <button class={@active_tab == "export" && "active"} phx-click="select_tab" phx-value-tab="export">
            Export
          </button>
        </div>
        <div class="tab-content">
          <%= if @active_tab == "components" do %>
            <div class="component-list">
              <%= for type <- @component_types do %>
                <button phx-click="add_component" phx-value-type={type}>
                  <%= type %>
                </button>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>

      <!-- Center Canvas -->
      <div class="canvas-area">
        <div id="design-canvas" phx-hook="DesignCanvas" data-zoom={@zoom} data-grid-visible={@grid_visible} data-snap-to-grid={@snap_to_grid} data-grid-size={@grid_size}>
          <%= if Map.get(@design, :nodes, []) != [] do %>
            <%= for node <- @design.nodes do %>
              <div class="canvas-node">
                <span class="node-icon"><%= node_icon(node.type) %></span>
                <span class="node-type"><%= node.type %></span>
              </div>
            <% end %>
          <% else %>
            Canvas (empty)
          <% end %>
        </div>
      </div>

      <!-- Right Panel -->
      <div class="right-panel">
        <h3>Preview</h3>
        <div id="preview-panel">
          <%= if Map.get(@design, :nodes, []) != [] do %>
            <%= for node <- @design.nodes do %>
              <div class="preview-node">
                <%= preview_node(node) %>
              </div>
            <% end %>
          <% else %>
            Preview (empty)
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def handle_event("add_component", %{"type" => type}, socket) do
    design = socket.assigns.design

    case find_component(String.to_atom(type)) do
      nil ->
        {:noreply, socket}

      component_type ->
        props = default_props(component_type)
        node = %{type: component_type, props: props, children: []}
        updated_design = Design.add_node(design, node)
        generated_code = generate_code(updated_design, socket.assigns.export_format)

        socket =
          socket
          |> assign(:design, updated_design)
          |> assign(:generated_code, generated_code)

        {:noreply, socket}
    end
  end

  def handle_event("select_node", %{"id" => id}, socket) do
    {:noreply, assign(socket, :selected_node, id)}
  end

  def handle_event("update_property", %{"id" => id, "key" => key, "value" => value}, socket) do
    design = socket.assigns.design
    updated_design = Design.update_node_property(design, id, key, value)
    generated_code = generate_code(updated_design, socket.assigns.export_format)

    socket =
      socket
      |> assign(:design, updated_design)
      |> assign(:generated_code, generated_code)

    {:noreply, socket}
  end

  def handle_event("delete_node", %{"id" => id}, socket) do
    design = socket.assigns.design
    updated_design = Design.delete_node(design, id)
    generated_code = generate_code(updated_design, socket.assigns.export_format)

    socket =
      socket
      |> assign(:design, updated_design)
      |> assign(:generated_code, generated_code)
      |> assign(:selected_node, nil)

    {:noreply, socket}
  end

  def handle_event("clear_canvas", _params, socket) do
    new_design = Design.new()
    generated_code = generate_code(new_design, socket.assigns.export_format)

    socket =
      socket
      |> assign(:design, new_design)
      |> assign(:generated_code, generated_code)
      |> assign(:selected_node, nil)

    {:noreply, socket}
  end

  def handle_event("set_export_format", %{"format" => format}, socket) do
    generated_code = generate_code(socket.assigns.design, format)

    socket =
      socket
      |> assign(:export_format, format)
      |> assign(:generated_code, generated_code)

    {:noreply, socket}
  end

  def handle_event("select_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  # Private functions

  defp find_component(type) do
    if type in @component_types do
      type
    else
      nil
    end
  end

  defp default_props(component) when component in [:column, :row, :text, :button] do
    case component do
      :column -> %{"gap" => "space_md"}
      :row -> %{"gap" => "space_md"}
      :text -> %{"text" => "Sample"}
      :button -> %{"text" => "Button"}
    end
  end

  defp default_props(_component), do: %{}

  defp generate_code(design, format) do
    nodes = Map.get(design, :nodes, [])

    case format do
      "sigil" -> nodes_to_sigil(nodes)
      "dsl" -> nodes_to_dsl(nodes)
      "map" -> nodes_to_map(nodes)
      _ -> nodes_to_sigil(nodes)
    end
  end

  defp nodes_to_sigil(nodes) when is_list(nodes) do
    nodes
    |> Enum.map(&node_to_sigil/1)
    |> Enum.join("\n")
  end

  defp nodes_to_dsl(nodes) when is_list(nodes) do
    nodes
    |> Enum.map(&node_to_dsl/1)
    |> Enum.join("\n")
  end

  defp nodes_to_map(nodes) when is_list(nodes) do
    nodes
    |> Enum.map(&node_to_map/1)
    |> inspect()
  end

  defp node_to_sigil(%{type: type, props: props, children: children})
       when is_list(children) and children != [] do
    props_str = props_to_sigil(props)
    children_str = nodes_to_sigil(children)
    "<#{type}#{props_str}>\n#{children_str}\n</#{type}>"
  end

  defp node_to_sigil(%{type: type, props: props}) do
    props_str = props_to_sigil(props)
    "<#{type}#{props_str} />"
  end

  defp node_to_sigil(_), do: ""

  defp node_to_dsl(_node), do: "# DSL output"
  defp node_to_map(_node), do: %{}

  defp props_to_sigil(props) when is_map(props) do
    props
    |> Enum.map(fn {k, v} -> " #{k}=\"#{v}\"" end)
    |> Enum.join("")
  end

  defp props_to_sigil(_), do: ""

  defp node_icon(:column), do: "📊"
  defp node_icon(:row), do: "➡️"
  defp node_icon(:text), do: "📝"
  defp node_icon(:button), do: "🔘"
  defp node_icon(_), do: "❓"

  defp preview_node(%{type: :text, props: props}) do
    text = Map.get(props, "text", "Sample")
    "<span>#{text}</span>"
  end

  defp preview_node(%{type: :button, props: props}) do
    text = Map.get(props, "text", "Button")
    "<button>#{text}</button>"
  end

  defp preview_node(_), do: "<div>Unknown</div>"
end
