defmodule Dala.Designer.Codegen do
  @moduledoc """
  Generates Elixir screen module source code from Dala UI trees.

  Outputs Spark DSL style with snake_case entities.

  UI trees use the map format: `%{type: :atom, props: %{...}, children: [...]}`.
  """

  @event_handler_props [
    :on_tap,
    :on_long_press,
    :on_double_tap,
    :on_change,
    :on_toggle,
    :on_press,
    :on_submit,
    :on_refresh,
    :on_dismiss,
    :on_tab_select,
    :on_end_reached,
    :on_scroll,
    :on_focus,
    :on_blur,
    :on_select,
    :on_action,
    :on_remove,
    :on_leading,
    :on_page_change
  ]

  # Components where the first prop is a string/binary content prop — rendered as
  # a positional arg in DSL style (e.g. `text "Hello"`).
  # Determined from the component registry: the first prop must be :text or
  # another string-typed content prop.
  @positional_arg_types [:text, :button, :text_field]

  # ── Public API ──────────────────────────────────────────────────────────────

  @doc "Generate DSL-style screen module source."
  def generate_dsl(module_name, ui_tree, opts \\ []) do
    tree = normalize_tree(ui_tree)
    handlers = extract_handlers(tree)
    module_str = module_name_to_string(module_name)
    attributes = Keyword.get(opts, :attributes, [])

    attr_lines = render_dsl_attributes(attributes)
    screen_body = render_dsl_node(tree, 3)
    handler_clauses = render_dsl_handlers(handlers)

    attr_block =
      if attr_lines == "" do
        ""
      else
        "\n#{attr_lines}\n"
      end

    """
    defmodule #{module_str} do
      use Dala.Spark.Dsl

      dala do#{attr_block}
        screen name: #{inspect(screen_name(module_str))} do
    #{screen_body}
        end
      end
    #{handler_clauses}end
    """
    |> String.trim_trailing()
  end

  @doc """
  Generate DSL-style screen module source with `@doc` annotations on
  `handle_event/3` stubs.

  Each handler's `@doc` references the component types that can trigger it,
  making it easier to understand the event flow at a glance.

  ## Options

  * `:attributes` — list of `{name, type, default}` tuples for DSL attributes
  * `:component_map` — optional pre-computed map of handler => [component_types]
    (useful for avoiding re-traversal when caller already has this info)

  ## Example output

      def handle_event(:increment, _params, socket) do
        @doc "Triggered by: text, button"
        {:noreply, socket}
      end

  """
  def generate_dsl_with_docs(module_name, ui_tree, opts \\ []) do
    tree = normalize_tree(ui_tree)
    handlers = extract_handlers(tree)
    module_str = module_name_to_string(module_name)
    attributes = Keyword.get(opts, :attributes, [])

    component_map =
      Keyword.get(opts, :component_map, build_component_map(tree))

    attr_lines = render_dsl_attributes(attributes)
    screen_body = render_dsl_node(tree, 3)
    handler_clauses = render_dsl_handlers_with_docs(handlers, component_map)

    attr_block =
      if attr_lines == "" do
        ""
      else
        "\n#{attr_lines}\n"
      end

    """
    defmodule #{module_str} do
      use Dala.Spark.Dsl

      dala do#{attr_block}
        screen name: #{inspect(screen_name(module_str))} do
    #{screen_body}
        end
      end
    #{handler_clauses}end
    """
    |> String.trim_trailing()
  end

  @doc "Extract event handler names from a UI tree."
  def extract_handlers(ui_tree) do
    ui_tree
    |> collect_handlers()
    |> Enum.uniq()
    |> Enum.sort()
  end

  # ── Normalization ───────────────────────────────────────────────────────────

  defp normalize_tree(tree) when is_list(tree) do
    case tree do
      [single] -> normalize_tree(single)
      many -> %{type: :column, props: %{}, children: Enum.map(many, &normalize_tree/1)}
    end
  end

  defp normalize_tree(%{type: _, props: _, children: _} = node), do: node

  defp normalize_tree(%{type: type} = node) when is_atom(type) do
    %{
      type: type,
      props: Map.get(node, :props, %{}),
      children: Map.get(node, :children, [])
    }
  end

  defp normalize_tree(%{"type" => type, "props" => props, "children" => children}) do
    %{
      type: type,
      props: to_atom_keys(props || %{}),
      children: Enum.map(children || [], &normalize_tree/1)
    }
  end

  defp normalize_tree(%{"type" => type} = node) when is_atom(type) do
    %{
      type: type,
      props: to_atom_keys(Map.get(node, "props", %{})),
      children: Enum.map(Map.get(node, "children", []), &normalize_tree/1)
    }
  end

  defp to_atom_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} -> {k, v}
    end)
  rescue
    ArgumentError ->
      Map.new(map, fn
        {k, v} when is_binary(k) -> {String.to_atom(k), v}
        {k, v} -> {k, v}
      end)
  end

  # ── Handler extraction ──────────────────────────────────────────────────────

  defp collect_handlers(%{props: props, children: children}) do
    props = props || %{}
    children = children || []

    from_props =
      for key <- @event_handler_props,
          value = Map.get(props, key),
          value != nil,
          reduce: [] do
        acc -> [extract_handler_tag(value) | acc]
      end

    from_children = Enum.flat_map(children, &collect_handlers/1)
    from_props ++ from_children
  end

  defp collect_handlers(_), do: []

  # {self(), :tag} → :tag
  defp extract_handler_tag({_pid, tag}) when is_atom(tag), do: tag
  # bare atom → :atom
  defp extract_handler_tag(tag) when is_atom(tag), do: tag
  # anything else — best-effort string representation
  defp extract_handler_tag(other), do: other

  # ── DSL rendering ───────────────────────────────────────────────────────────

  defp render_dsl_node(%{"type" => type, "props" => props, "children" => children}, depth) do
    render_dsl_node(%{type: type, props: props, children: children}, depth)
  end

  defp render_dsl_node(%{type: type, props: props, children: children}, depth) do
    indent = String.duplicate("  ", depth)
    entity = type
    has_children = children != []
    is_positional_arg = type in @positional_arg_types

    {positional, keyword_props} = split_dsl_props(props, type)

    if has_children do
      child_lines =
        children
        |> Enum.map(&render_dsl_node(&1, depth + 1))
        |> Enum.join("\n")

      props_str = render_dsl_keyword_props(keyword_props, is_positional_arg, positional, type)

      if props_str == "" do
        "#{indent}#{entity} do\n#{child_lines}\n#{indent}end"
      else
        "#{indent}#{entity} #{props_str} do\n#{child_lines}\n#{indent}end"
      end
    else
      props_str = render_dsl_keyword_props(keyword_props, is_positional_arg, positional, type)

      if props_str == "" do
        "#{indent}#{entity}"
      else
        "#{indent}#{entity} #{props_str}"
      end
    end
  end

  defp split_dsl_props(nil, _type), do: {nil, []}

  defp split_dsl_props(props, type) do
    # For components in @positional_arg_types, the first prop from the
    # component registry is used as the positional arg. For all other
    # components, every prop is rendered as a keyword arg.
    positional_key =
      if type in @positional_arg_types do
        first_prop = Dala.Ui.Component.props(type) |> List.first()
        first_prop
      else
        nil
      end

    positional =
      if positional_key && Map.has_key?(props, positional_key),
        do: Map.get(props, positional_key),
        else: nil

    keyword_props =
      props
      |> Map.to_list()
      |> Enum.reject(fn {k, v} -> k == positional_key or v == nil or v == false end)
      |> Enum.sort_by(fn {k, _} ->
        if k in @event_handler_props, do: 1, else: 0
      end)

    {positional, keyword_props}
  end

  defp render_dsl_keyword_props([], false, nil), do: ""

  defp render_dsl_keyword_props([], true, positional) when is_binary(positional) do
    inspect(positional)
  end

  defp render_dsl_keyword_props(keyword_props, is_positional_arg, positional, type) do
    parts =
      if positional && is_positional_arg do
        [render_dsl_value(positional) | Enum.map(keyword_props, &render_dsl_kv/1)]
      else
        all_props =
          if positional do
            # Non-positional component that still has a "first prop" value —
            # render it as a keyword arg (e.g. icon name: :star)
            first_key = Dala.Ui.Component.props(type) |> List.first()
            [{first_key, positional} | keyword_props]
          else
            keyword_props
          end

        Enum.map(all_props, &render_dsl_kv/1)
      end

    Enum.join(parts, ", ")
  end

  defp render_dsl_kv({key, value}) do
    "#{key}: #{render_dsl_value(value)}"
  end

  defp render_dsl_value({_pid, tag}) when is_atom(tag), do: ":#{tag}"
  defp render_dsl_value(value) when is_boolean(value), do: "#{value}"
  defp render_dsl_value(value) when is_atom(value), do: ":#{value}"
  defp render_dsl_value(value) when is_binary(value), do: inspect(value)
  defp render_dsl_value(value) when is_integer(value) or is_float(value), do: "#{value}"
  defp render_dsl_value(value), do: inspect(value)

  defp render_dsl_attributes([]), do: ""

  defp render_dsl_attributes(attributes) do
    lines =
      for {name, type, default} <- attributes do
        default_str =
          if default != nil do
            ", default: #{inspect(default)}"
          else
            ""
          end

        "      attribute #{inspect(name)}, #{inspect(type)}#{default_str}"
      end
      |> Enum.join("\n")

    "    attributes do\n#{lines}\n    end"
  end

  defp render_dsl_handlers([]), do: ""

  defp render_dsl_handlers(handlers) do
    clauses =
      for handler <- handlers do
        """
          def handle_event(#{inspect(handler)}, _params, socket) do
            {:noreply, socket}
          end
        """
      end
      |> Enum.join("\n")

    "\n#{clauses}\n"
  end

  defp render_dsl_handlers_with_docs([], _component_map), do: ""

  defp render_dsl_handlers_with_docs(handlers, component_map) do
    clauses =
      for handler <- handlers do
        component_types = Map.get(component_map, handler, [])
        doc_line = render_handler_doc(component_types)

        """
          #{doc_line}
          def handle_event(#{inspect(handler)}, _params, socket) do
            {:noreply, socket}
          end
        """
      end
      |> Enum.join("\n")

    "\n#{clauses}\n"
  end

  defp render_handler_doc([]), do: ""

  defp render_handler_doc(component_types) do
    types_str = Enum.map_join(component_types, ", ", &"`#{&1}`")
    ~s(@doc "Triggered by: #{types_str}")
  end

  # ── Component map for doc generation ───────────────────────────────────────

  @doc """
  Build a map of handler => [component_types] by walking the UI tree.
  Used by `generate_dsl_with_docs/3` to annotate handlers with their sources.
  """
  def build_component_map(ui_tree) do
    ui_tree
    |> do_build_component_map()
    |> Enum.reduce(%{}, fn {handler, type}, acc ->
      Map.update(acc, handler, [type], &[type | &1])
    end)
    |> Map.new(fn {k, v} -> {k, Enum.uniq(v) |> Enum.sort()} end)
  end

  defp do_build_component_map(%{props: props, children: children, type: type}) do
    props = props || %{}
    children = children || []

    from_props =
      for key <- @event_handler_props,
          value = Map.get(props, key),
          value != nil,
          reduce: [] do
        acc -> [{extract_handler_tag(value), type} | acc]
      end

    from_children = Enum.flat_map(children, &do_build_component_map/1)
    from_props ++ from_children
  end

  defp do_build_component_map(_), do: []

  # ── Helpers ─────────────────────────────────────────────────────────────────

  defp module_name_to_string(name) when is_atom(name), do: Atom.to_string(name)
  defp module_name_to_string(name) when is_binary(name), do: name

  defp screen_name(module_str) do
    module_str
    |> String.split(".")
    |> List.last()
    |> Macro.underscore()
    |> String.to_atom()
  end
end
