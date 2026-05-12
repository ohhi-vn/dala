defmodule Dala.Spark.Dsl.Entities do
  @moduledoc """
  Generates entity structs and Spark entity definitions from the Component registry.

  This module is `use`d by `Dala.Spark.Dsl` to inject all entity definitions
  as module attributes BEFORE `Spark.Dsl.Extension` is invoked.

  When you add a component to `Dala.Ui.Component`, it automatically appears
  here — no manual entity definitions needed.
  """

  @doc false
  defmacro __using__(_opts) do
    leaf_components = Dala.Ui.Component.leaf_components()
    container_components = Dala.Ui.Component.container_components()

    leaf_entity_structs = generate_struct_definitions(leaf_components)
    container_entity_structs = generate_struct_definitions(container_components)

    leaf_entity_attrs = generate_entity_attrs(leaf_components, false)
    container_entity_attrs = generate_entity_attrs(container_components, true)

    # Build concrete entity structs for the @all_entities list
    leaf_entities = build_entity_list(leaf_components, false)
    container_entities = build_entity_list(container_components, true, leaf_entities)

    all_entities_value = container_entities ++ leaf_entities

    quote do
      # ── All struct definitions first ───────────────────────────────────────
      unquote_splicing(leaf_entity_structs)
      unquote_splicing(container_entity_structs)

      # ── Leaf entity module attributes ─────────────────────────────────────
      unquote_splicing(leaf_entity_attrs)

      # @leaf_entities is referenced by container entity attributes
      @leaf_entities unquote(Macro.escape(leaf_entities))

      # ── Container entity module attributes (reference @leaf_entities) ─────
      unquote_splicing(container_entity_attrs)

      @all_entities unquote(Macro.escape(all_entities_value))
    end
  end

  defp generate_struct_definitions(components) do
    Enum.map(components, fn {_name, comp} ->
      struct_name = struct_module_name(comp.name)
      fields = comp.props ++ [__spark_metadata__: nil]

      quote do
        defmodule unquote(struct_name) do
          @moduledoc false
          defstruct unquote(fields)
        end
      end
    end)
  end

  defp generate_entity_attrs(components, _is_container) do
    Enum.map(components, fn {_name, comp} ->
      struct_name = struct_module_name(comp.name)
      entity_name = comp.name
      schema = Dala.Ui.Component.prop_schema(comp.name)
      is_container = comp.category == :container

      args =
        cond do
          entity_name in [:list, :native_view, :carousel] ->
            [:id]

          entity_name in [
            :divider,
            :spacer,
            :status_bar,
            :refresh_control,
            :activity_indicator,
            :progress_bar,
            :safe_area
          ] ->
            []

          true ->
            case comp.props do
              [first | _] -> [first]
              [] -> []
            end
        end

      examples = Enum.take(comp.examples, 2)

      # Build the struct AST: %Spark.Dsl.Entity{...}
      struct_ast =
        if is_container do
          quote do
            %Spark.Dsl.Entity{
              name: unquote(entity_name),
              target: unquote(struct_name),
              describe: unquote(comp.doc),
              args: unquote(args),
              examples: unquote(examples),
              schema: unquote(Macro.escape(schema)),
              entities: [children: @leaf_entities],
              recursive_as: unquote(comp.children_key)
            }
          end
        else
          quote do
            %Spark.Dsl.Entity{
              name: unquote(entity_name),
              target: unquote(struct_name),
              describe: unquote(comp.doc),
              args: unquote(args),
              examples: unquote(examples),
              schema: unquote(Macro.escape(schema))
            }
          end
        end

      # Wrap in @attribute_name: {@: [ctx: Elixir], [attribute_name, [ctx: Elixir], [struct_ast]]}
      {:@, [context: Elixir, imports: [{1, Kernel}]],
       [{entity_name, [context: Elixir], [struct_ast]}]}
    end)
  end

  defp build_entity_list(components, is_container, leaf_entities \\ nil) do
    Enum.map(components, fn {_name, comp} ->
      struct_name = struct_module_name(comp.name)
      entity_name = comp.name
      schema = Dala.Ui.Component.prop_schema(comp.name)

      args =
        cond do
          entity_name in [:list, :native_view, :carousel] ->
            [:id]

          entity_name in [
            :divider,
            :spacer,
            :status_bar,
            :refresh_control,
            :activity_indicator,
            :progress_bar,
            :safe_area
          ] ->
            []

          true ->
            case comp.props do
              [first | _] -> [first]
              [] -> []
            end
        end

      examples = Enum.take(comp.examples, 2)

      if is_container do
        %Spark.Dsl.Entity{
          name: entity_name,
          target: struct_name,
          describe: comp.doc,
          args: args,
          examples: examples,
          schema: schema,
          entities: [children: leaf_entities || []],
          recursive_as: comp.children_key
        }
      else
        %Spark.Dsl.Entity{
          name: entity_name,
          target: struct_name,
          describe: comp.doc,
          args: args,
          examples: examples,
          schema: schema
        }
      end
    end)
  end

  defp struct_module_name(name) do
    name
    |> Atom.to_string()
    |> Macro.camelize()
    |> then(&Module.concat(Dala.Spark.Dsl, &1))
  end
end
