defmodule Dala.Spark.Transformers.Render do
  @moduledoc """
  Spark transformer that generates the `render/1` function from DSL entities.

  Walks the entity tree (screen → container children → leaves) and produces
  a `render/1` that builds the same node maps `Dala.Ui.Widgets` functions return:

      %{type: :column, props: %{...}, children: [...]}

  Container entities carry a `:children` field populated by Spark's
  `recursive_as` mechanism. Leaf entities have no children.

  Type mapping is derived dynamically from `Dala.Ui.Component` registry at
  compile time — when a component is added to the registry, the DSL render
  transformer picks it up automatically.
  """

  use Spark.Dsl.Transformer

  # Regex compiled at runtime to avoid OTP 28 compile-time literal issue
  # (AGENTS.md rule #9).
  @at_ref_regex Regex.compile!("@([a-zA-Z_]\\w*)")

  # Struct → type mapping derived from Component registry at compile time.
  @struct_to_type (for {name, comp} <- Dala.Ui.Component.components(), into: %{} do
                     struct_module =
                       Module.concat(Dala.Spark.Dsl, Macro.camelize(Atom.to_string(name)))

                     {struct_module, comp.type}
                   end)

  @impl true
  def transform(dsl_state) do
    entities = Spark.Dsl.Transformer.get_entities(dsl_state, [:screen])

    case entities do
      [] ->
        {:ok, dsl_state}

      screen_entities ->
        render_ast = build_children_ast(screen_entities)

        render_fn =
          quote do
            def render(assigns) do
              unquote(render_ast)
            end
          end

        {:ok, Spark.Dsl.Transformer.eval(dsl_state, [], render_fn)}
    end
  end

  # ── AST builders ──────────────────────────────────────────────────────────

  defp build_children_ast([]) do
    quote do: []
  end

  defp build_children_ast([single]) do
    quote do: [unquote(build_node_ast(single))]
  end

  defp build_children_ast(entities) when is_list(entities) do
    nodes = Enum.map(entities, &build_node_ast/1)
    quote do: unquote(nodes)
  end

  defp build_node_ast(%{type: :conditional} = entity) do
    props_ast = build_conditional_props_ast(entity)
    then_ast = build_children_ast(Map.get(entity, :then_children, []))
    else_ast = build_children_ast(Map.get(entity, :else_children, []))

    quote do
      %{
        type: :conditional,
        props: unquote(props_ast),
        children: [],
        then_children: unquote(then_ast),
        else_children: unquote(else_ast)
      }
    end
  end

  defp build_node_ast(%{type: :list_render} = entity) do
    props_ast = build_list_render_props_ast(entity)
    for_args = Map.get(entity, :for_args)

    quote do
      %{
        type: :list_render,
        props: unquote(props_ast),
        children: [],
        for_args: unquote(Macro.escape(for_args))
      }
    end
  end

  defp build_node_ast(entity) do
    type = struct_to_type(entity.__struct__)
    props_ast = build_props_ast(entity)
    children = Map.get(entity, :children, [])
    children_ast = build_children_ast(children)

    quote do
      %{type: unquote(type), props: unquote(props_ast), children: unquote(children_ast)}
    end
  end

  # ── Type mapping (dynamic from Component registry) ─────────────────────────

  defp struct_to_type(struct_module) do
    Map.get_lazy(@struct_to_type, struct_module, fn ->
      struct_module
      |> Module.split()
      |> List.last()
      |> Macro.underscore()
      |> String.to_atom()
    end)
  end

  # ── Props building ────────────────────────────────────────────────────────

  defp build_props_ast(entity) do
    struct_module = entity.__struct__

    fields =
      struct_module.__struct__()
      |> Map.from_struct()
      |> Map.keys()
      |> Enum.filter(&(&1 not in [:__spark_metadata__, :children]))

    pairs =
      fields
      |> Enum.filter(&(Map.get(entity, &1) != nil))
      |> Enum.map(fn field ->
        value = Map.get(entity, field)
        key = field
        val_ast = build_value_ast(value, key)
        {key, val_ast}
      end)

    {:%{}, [], pairs}
  end

  defp build_conditional_props_ast(entity) do
    props = Map.get(entity, :props, %{})
    pairs = Enum.map(props, fn {key, value} -> {key, build_value_ast(value, key)} end)
    {:%{}, [], pairs}
  end

  defp build_list_render_props_ast(entity) do
    props = Map.get(entity, :props, %{})
    pairs = Enum.map(props, fn {key, value} -> {key, build_value_ast(value, key)} end)
    {:%{}, [], pairs}
  end

  defp build_value_ast(value, _key) when is_binary(value) do
    case process_at_refs_in_string(value) do
      {:literal, literal} -> literal
      {:interpolated, ast} -> ast
    end
  end

  defp build_value_ast(value, _key) when is_list(value) do
    Enum.map(value, &build_value_ast(&1, nil))
  end

  defp build_value_ast(value, _key) when is_map(value) do
    pairs =
      Enum.map(value, fn {k, v} ->
        {build_value_ast(k, nil), build_value_ast(v, nil)}
      end)

    {:%{}, [], pairs}
  end

  defp build_value_ast(value, _key) do
    Macro.escape(value)
  end

  # ── @ref processing ───────────────────────────────────────────────────────

  defp process_at_refs_in_string(string) do
    matches =
      Regex.scan(@at_ref_regex, string, return: :index)
      |> Enum.map(fn [{start, len}, {key_start, key_len}] ->
        %{
          full_start: start,
          full_end: start + len,
          key_start: key_start,
          key_len: key_len
        }
      end)

    if matches == [] do
      {:literal, Macro.escape(string)}
    else
      parts = build_interpolation_parts(string, matches)
      {:interpolated, parts}
    end
  end

  defp build_interpolation_parts(string, matches) do
    segments =
      matches
      |> Enum.reduce({0, []}, fn match, {offset, acc} ->
        literal_before = binary_part(string, offset, match.full_start - offset)
        key = binary_part(string, match.key_start, match.key_len)
        key_atom = String.to_atom(key)

        acc =
          acc
          |> maybe_add_literal(literal_before)
          |> Kernel.++([quote(do: to_string(assigns[unquote(key_atom)]))])

        {match.full_end, acc}
      end)
      |> then(fn {offset, acc} ->
        trailing = binary_part(string, offset, byte_size(string) - offset)
        maybe_add_literal(acc, trailing)
      end)

    case segments do
      [single] -> single
      multiple -> combine_with_concat(multiple)
    end
  end

  defp maybe_add_literal(acc, ""), do: acc
  defp maybe_add_literal(acc, literal), do: acc ++ [literal]

  defp combine_with_concat([a, b | rest]) do
    base = quote(do: unquote(a) <> unquote(b))

    Enum.reduce(rest, base, fn part, acc ->
      quote(do: unquote(acc) <> unquote(part))
    end)
  end
end
