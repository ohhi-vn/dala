defmodule Dala.Preview.Codegen do
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
    :on_blur
  ]

  # Components where the primary string content is a positional arg in DSL style
  @text_arg_types [:text, :button, :icon, :toggle, :text_field, :list_item]

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
      props: props || %{},
      children: Enum.map(children || [], &normalize_tree/1)
    }
  end

  defp normalize_tree(%{"type" => type} = node) when is_atom(type) do
    %{
      type: type,
      props: Map.get(node, "props", %{}),
      children: Enum.map(Map.get(node, "children", []), &normalize_tree/1)
    }
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
    is_text_arg = type in @text_arg_types

    {positional, keyword_props} = split_dsl_props(props, type)

    if has_children do
      child_lines =
        children
        |> Enum.map(&render_dsl_node(&1, depth + 1))
        |> Enum.join("\n")

      props_str = render_dsl_keyword_props(keyword_props, is_text_arg, positional)

      if props_str == "" do
        "#{indent}#{entity} do\n#{child_lines}\n#{indent}end"
      else
        "#{indent}#{entity} #{props_str} do\n#{child_lines}\n#{indent}end"
      end
    else
      props_str = render_dsl_keyword_props(keyword_props, is_text_arg, positional)

      if props_str == "" do
        "#{indent}#{entity}"
      else
        "#{indent}#{entity} #{props_str}"
      end
    end
  end

  defp split_dsl_props(nil, _type), do: {nil, []}

  defp split_dsl_props(props, type) do
    text_key = if type in @text_arg_types, do: :text, else: nil

    positional =
      if text_key && Map.has_key?(props, text_key), do: Map.get(props, text_key), else: nil

    keyword_props =
      props
      |> Map.to_list()
      |> Enum.reject(fn {k, v} -> k == text_key or v == nil or v == false end)
      |> Enum.sort_by(fn {k, _} ->
        if k in @event_handler_props, do: 1, else: 0
      end)

    {positional, keyword_props}
  end

  defp render_dsl_keyword_props([], false, nil), do: ""

  defp render_dsl_keyword_props([], true, positional) when is_binary(positional) do
    inspect(positional)
  end

  defp render_dsl_keyword_props(keyword_props, is_text_arg, positional) do
    parts =
      if positional && is_text_arg do
        [inspect(positional) | Enum.map(keyword_props, &render_dsl_kv/1)]
      else
        all_props =
          if positional do
            [{:text, positional} | keyword_props]
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
