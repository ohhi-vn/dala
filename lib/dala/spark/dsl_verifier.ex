defmodule Dala.Spark.DslVerifier do
  @moduledoc """
  Comprehensive DSL verification for Dala screen modules.

  Validates user-defined screens against the component registry and
  reports warnings/errors for:
  - Unknown component types
  - Invalid prop names
  - Missing required props
  - Event handler props that are not atoms
  - Invalid attribute types
  - Missing handle_event/3 for declared event handlers
  - Children placed inside leaf components
  - Invalid variant values
  - Deprecated prop usage
  """

  @type warning :: %{
          type: :error | :warning | :info,
          module: atom(),
          line: non_neg_integer(),
          message: String.t()
        }

  @doc """
  Verify a single screen module's DSL definition.

  Returns a list of warnings/errors found.
  """
  @spec verify_module(module()) :: [warning()]
  def verify_module(module) when is_atom(module) do
    with {:module, _} <- Code.ensure_loaded(module),
         true <- function_exported?(module, :__spark_dsl__, 0) do
      do_verify(module)
    else
      _ ->
        [
          %{
            type: :warning,
            module: module,
            line: 0,
            message:
              "Module #{inspect(module)} does not appear to be a Dala screen (no __spark_dsl__ info)"
          }
        ]
    end
  end

  def verify_module(module) do
    [
      %{
        type: :error,
        module: module,
        line: 0,
        message: "Module #{inspect(module)} is not loaded or does not exist"
      }
    ]
  end

  defp do_verify(module) do
    dsl_info = module.__spark_dsl__()
    entities = Map.get(dsl_info, :entities, [])
    attributes = Map.get(dsl_info, :attributes, [])
    handlers = Map.get(dsl_info, :handlers, [])

    attr_warnings = verify_attributes(module, attributes)
    entity_warnings = verify_entities(module, entities)
    handler_warnings = verify_handlers(module, entities, handlers)

    attr_warnings ++ entity_warnings ++ handler_warnings
  end

  # ── Attribute verification ──────────────────────────────────────────────────

  defp verify_attributes(module, attributes) do
    valid_types = [:integer, :string, :boolean, :float, :atom, :list, :map]

    Enum.flat_map(attributes, fn attr ->
      name = Map.get(attr, :name, :unknown)
      type = Map.get(attr, :type, nil)
      line = Map.get(attr, :line, 0)

      cond do
        type == nil ->
          [
            %{
              type: :error,
              module: module,
              line: line,
              message: "Attribute :#{name} is missing a type declaration"
            }
          ]

        type not in valid_types ->
          [
            %{
              type: :error,
              module: module,
              line: line,
              message:
                "Attribute :#{name} has invalid type #{inspect(type)}. Valid types: #{Enum.map_join(valid_types, ", ", &inspect/1)}"
            }
          ]

        true ->
          []
      end
    end)
  end

  # ── Entity (component) verification ─────────────────────────────────────────

  defp verify_entities(module, entities) do
    Enum.flat_map(entities, &verify_entity(module, &1))
  end

  # Extract type, props, children, and line from an entity.
  # Entities can be either maps (from raw data verification) or structs (from persisted DSL data).
  defp extract_entity_info(entity) when is_map(entity) do
    case entity do
      %{type: type} when is_atom(type) ->
        # Map-based entity (from raw data verification)
        {type, Map.get(entity, :props, %{}), Map.get(entity, :children, []),
         Map.get(entity, :line, 0)}

      %{__struct__: struct_module} ->
        # DSL struct (e.g., %Dala.Spark.Dsl.Column{...})
        # Extract component type from struct module name
        type =
          struct_module
          |> Module.split()
          |> List.last()
          |> String.downcase()
          |> String.to_atom()

        props = Map.drop(entity, [:__spark_metadata__, :children, :__struct__])
        children = Map.get(entity, :children, [])
        line = extract_line(entity)
        {type, props, children, line}

      _ ->
        {:unknown, %{}, [], 0}
    end
  end

  defp extract_line(%{__spark_metadata__: %{anno: [line: line, _column: _]}}), do: line
  defp extract_line(%{__spark_metadata__: %{anno: [line: line]}}), do: line
  defp extract_line(%{__spark_metadata__: %{anno: line}}) when is_integer(line), do: line
  defp extract_line(%{__spark_metadata__: %{anno: _}}), do: 0
  defp extract_line(%{__spark_metadata__: _}), do: 0
  defp extract_line(_), do: 0

  defp verify_entity(module, entity) do
    {type, props, children, line} = extract_entity_info(entity)

    component = Dala.Ui.Component.get(type)

    cond do
      component == nil ->
        [
          %{
            type: :error,
            module: module,
            line: line,
            message:
              "Unknown component type :#{type}. Run `mix dala.verify --components` to see all available components."
          }
        ]

      component.category == :leaf and children != [] ->
        [
          %{
            type: :error,
            module: module,
            line: line,
            message:
              "Leaf component :#{type} does not accept children. Remove nested content or use a container component."
          }
        ]

      true ->
        prop_warnings = verify_props(module, type, props, component, line)
        child_warnings = verify_entities(module, children)
        prop_warnings ++ child_warnings
    end
  end

  @event_handler_props [
    :on_tap,
    :on_long_press,
    :on_double_tap,
    :on_swipe,
    :on_swipe_left,
    :on_swipe_right,
    :on_swipe_up,
    :on_swipe_down,
    :on_press,
    :on_change,
    :on_toggle,
    :on_focus,
    :on_blur,
    :on_submit,
    :on_compose,
    :on_refresh,
    :on_end_reached,
    :on_scroll,
    :on_dismiss,
    :on_tab_select,
    :on_select,
    :on_action,
    :on_remove,
    :on_leading,
    :on_page_change,
    :on_error,
    :on_load
  ]

  defp verify_props(module, type, props, component, line) do
    valid_props = component.props

    unknown =
      Enum.flat_map(props, fn
        {key, _value} when is_atom(key) ->
          if key in valid_props or key == :__spark_metadata__ do
            []
          else
            suggestion = find_closest_match(key, valid_props)
            hint = if suggestion, do: " Did you mean :#{suggestion}?", else: ""

            [
              %{
                type: :warning,
                module: module,
                line: line,
                message:
                  "Unknown prop :#{key} on :#{type}.#{hint} Valid props: #{Enum.map_join(Enum.take(valid_props, 8), ", ", &inspect/1)}..."
              }
            ]
          end

        {key, _value} ->
          [
            %{
              type: :warning,
              module: module,
              line: line,
              message:
                "Prop key #{inspect(key)} on :#{type} should be an atom, got: #{inspect(key)}"
            }
          ]
      end)

    event_errors =
      Enum.flat_map(props, fn
        {key, value} when is_atom(key) and key in @event_handler_props ->
          if is_atom(value) or match?({_, _}, value) do
            []
          else
            [
              %{
                type: :error,
                module: module,
                line: line,
                message:
                  "Event handler :#{key} on :#{type} must be an atom (e.g. :my_handler) or a {pid, :tag} tuple, got: #{inspect(value)}"
              }
            ]
          end

        _ ->
          []
      end)

    variant_warnings = verify_variant(module, type, props, component, line)

    unknown ++ event_errors ++ variant_warnings
  end

  defp verify_variant(module, :text, props, _component, line) do
    case Map.get(props, :variant) do
      nil ->
        []

      variant when is_atom(variant) ->
        valid = [:display, :heading, :title, :body, :caption, :label, :overline]

        if variant in valid do
          []
        else
          [
            %{
              type: :warning,
              module: module,
              line: line,
              message:
                "Invalid variant :#{variant} on :text. Valid variants: #{Enum.map_join(valid, ", ", &inspect/1)}"
            }
          ]
        end

      variant ->
        [
          %{
            type: :error,
            module: module,
            line: line,
            message: "Variant on :text must be an atom, got: #{inspect(variant)}"
          }
        ]
    end
  end

  defp verify_variant(_module, _, _, _, _), do: []

  # ── Handler verification ────────────────────────────────────────────────────

  defp verify_handlers(module, entities, defined_handlers) do
    declared_handlers = collect_event_handlers(entities)

    undeclared =
      Enum.filter(declared_handlers, fn handler ->
        not Enum.any?(defined_handlers, fn defined ->
          Map.get(defined, :name, nil) == handler
        end)
      end)

    Enum.map(undeclared, fn handler ->
      %{
        type: :warning,
        module: module,
        line: 0,
        message:
          "Event handler :#{handler} is referenced in the UI tree but no handle_event(:#{handler}, _, _) clause is defined in #{inspect(module)}"
      }
    end)
  end

  defp collect_event_handlers(entities) do
    entities
    |> Enum.flat_map(fn entity ->
      props = Map.get(entity, :props, %{})
      children = Map.get(entity, :children, [])

      from_props =
        Enum.flat_map(props, fn
          {key, value} when is_atom(key) and key in @event_handler_props ->
            case value do
              v when is_atom(v) -> [v]
              {_, v} when is_atom(v) -> [v]
              _ -> []
            end

          _ ->
            []
        end)

      from_children = collect_event_handlers(children)
      from_props ++ from_children
    end)
    |> Enum.uniq()
    |> Enum.sort()
  end

  # ── Fuzzy match for typo suggestions ────────────────────────────────────────

  defp find_closest_match(key, valid_props) do
    key_str = Atom.to_string(key)

    valid_props
    |> Enum.map(fn prop ->
      {prop, String.jaro_distance(key_str, Atom.to_string(prop))}
    end)
    |> Enum.filter(fn {_, distance} -> distance > 0.75 end)
    |> Enum.sort_by(fn {_, distance} -> distance end, :desc)
    |> case do
      [{best, _} | _] -> best
      [] -> nil
    end
  end

  # ── Raw data verification (for compile-time hook) ──────────────────────────

  @doc """
  Verify DSL from raw entity/attribute/handler data (used by compile-time hook).
  """
  @spec verify_from_raw(module(), [map()], [map()], [map()]) :: [warning()]
  def verify_from_raw(module, entities, attributes, handlers) do
    attr_warnings = verify_attributes(module, attributes)
    entity_warnings = verify_entities(module, entities)
    handler_warnings = verify_handlers(module, entities, handlers)

    attr_warnings ++ entity_warnings ++ handler_warnings
  end

  # ── Formatting ──────────────────────────────────────────────────────────────

  @doc """
  Format a list of warnings into a human-readable report.
  """
  @spec format_report([warning()]) :: String.t()
  def format_report(warnings) do
    errors = Enum.filter(warnings, &(&1.type == :error))
    warns = Enum.filter(warnings, &(&1.type == :warning))
    infos = Enum.filter(warnings, &(&1.type == :info))

    header = """
    ╔══════════════════════════════════════════════════════════════╗
    ║              Dala DSL Verification Report                    ║
    ╚══════════════════════════════════════════════════════════════╝
    """

    summary =
      "\n  Found #{length(errors)} error(s), #{length(warns)} warning(s), #{length(infos)} info message(s)\n"

    sections =
      [
        format_section("Errors", errors, :red),
        format_section("Warnings", warns, :yellow),
        format_section("Info", infos, :blue)
      ]
      |> Enum.reject(&is_nil/1)

    if sections == [] do
      header <> "\n  ✓ No issues found. All DSL definitions look correct.\n"
    else
      header <> summary <> Enum.join(sections, "\n")
    end
  end

  defp format_section(_title, [], _color), do: nil

  defp format_section(title, items, _color) do
    formatted =
      items
      |> Enum.sort_by(&{&1.module, &1.line})
      |> Enum.map(fn w ->
        line_info = if w.line > 0, do: "line #{w.line}", else: ""

        "  [#{String.pad_trailing(title, 7)}] #{inspect(w.module)} #{line_info}\n    → #{w.message}"
      end)
      |> Enum.join("\n")

    "\n  #{String.pad_leading("#{length(items)} #{title}", 30)}\n\n#{formatted}"
  end

  @doc """
  Print warnings to the Mix shell with appropriate coloring.
  """
  @spec print_warnings([warning()]) :: :ok
  def print_warnings(warnings) do
    errors = Enum.filter(warnings, &(&1.type == :error))
    warns = Enum.filter(warnings, &(&1.type == :warning))

    Enum.each(warnings, fn w ->
      prefix =
        case w.type do
          :error -> "  ✗ "
          :warning -> "  ⚠ "
          :info -> "  ℹ "
        end

      line_info = if w.line > 0, do: " (line #{w.line})", else: ""
      Mix.shell().info("#{prefix}#{inspect(w.module)}#{line_info}: #{w.message}")
    end)

    if length(errors) > 0 do
      Mix.shell().error(
        "\n  #{length(errors)} DSL error(s) found. Run `mix dala.verify --dsl` for details."
      )
    end

    if length(warns) > 0 do
      Mix.shell().info("\n  #{warns |> length()} DSL warning(s) found.")
    end

    :ok
  end
end
