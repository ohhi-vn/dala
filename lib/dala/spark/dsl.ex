defmodule Dala.Spark.Dsl do
  @moduledoc """
  Spark DSL for declarative Dala screens.

  Defines attributes for screen state and UI component entities that mirror
  `Dala.Ui.Component` one-to-one. All entity structs and definitions are
  auto-generated from the central component registry via `Dala.Spark.Dsl.Entities`.
  Container entities support nested children via Spark's `entities` + `recursive_as`.

  ## Usage

      defmodule MyApp.CounterScreen do
        use Dala.Spark.Dsl

        dala do
          attribute :count, :integer, default: 0

          screen name: :counter do
            column padding: :space_md, gap: :space_sm do
              text "Count: @count", text_size: :xl
              button "Increment", on_tap: :increment
            end
          end
        end

        def handle_event(:increment, _params, socket) do
          {:noreply, Dala.Socket.assign(socket, :count, socket.assigns.count + 1)}
        end
      end
  """

  # ── Attribute section ───────────────────────────────────────────────────

  defmodule Attribute do
    @moduledoc false
    defstruct name: nil, type: nil, default: nil, __spark_metadata__: nil
  end

  @attribute %Spark.Dsl.Entity{
    name: :attribute,
    target: Attribute,
    describe: "Define a screen assign with type and default value",
    args: [:name, :type],
    schema: [
      name: [type: :atom, required: true, doc: "Assign key"],
      type: [
        type: {:one_of, [:integer, :string, :boolean, :float, :atom, :list, :map]},
        required: true,
        doc: "Value type"
      ],
      default: [type: :any, doc: "Default value (nil if omitted)"]
    ]
  }

  @attributes %Spark.Dsl.Section{
    name: :attributes,
    describe: "Declare screen state attributes",
    top_level?: true,
    entities: [@attribute]
  }

  # ── Component entities (auto-generated from Dala.Ui.Component) ──────────
  use Dala.Spark.Dsl.Entities

  # ── Screen section ──────────────────────────────────────────────────────

  @screen %Spark.Dsl.Section{
    name: :screen,
    describe: "Screen definition with UI components",
    top_level?: true,
    schema: [
      name: [type: :atom, required: true, doc: "Screen identifier"]
    ],
    entities: @all_entities
  }

  # ── PubSub section (from Dala.Spark.Pubsub) ────────────────────────────

  defmodule PubSubSubscription do
    @moduledoc false
    defstruct topic: nil, on_message: nil, __spark_metadata__: nil
  end

  @pubsub_subscription %Spark.Dsl.Entity{
    name: :subscribe,
    target: PubSubSubscription,
    describe: "Subscribe to a PubSub topic with a message handler",
    args: [:topic],
    schema: [
      topic: [type: :string, required: true, doc: "Topic to subscribe to"],
      on_message: [
        type: :atom,
        required: true,
        doc: "Handler function name to call when message arrives"
      ]
    ]
  }

  @pubsub_section %Spark.Dsl.Section{
    name: :pubsub,
    describe: "Declare PubSub subscriptions for this screen",
    entities: [@pubsub_subscription]
  }

  # ── Extension registration ──────────────────────────────────────────────

  use Spark.Dsl.Extension,
    sections: [@attributes, @screen, @pubsub_section],
    transformers: [
      Dala.Spark.Transformers.GenerateMount,
      Dala.Spark.Transformers.Render,
      Dala.Spark.Transformers.Pubsub
    ],
    verifiers: [__MODULE__.Verifier]

  use Spark.Dsl,
    many_extension_kinds: [:dala],
    default_extensions: [dala: [__MODULE__]]

  # ── Custom screen/2 and attributes/2 macros ────────────────────────────
  # Spark's build_section skips defining section macros for top-level
  # sections (top_level?: true). We define them here manually to support
  # the standard Elixir calling convention: `screen name: :foo do ... end`.

  # Build a lookup map of component name → struct module at compile time
  @component_structs (for {name, _comp} <- Dala.Ui.Component.components(), into: %{} do
                        {name,
                         Module.concat(Dala.Spark.Dsl, Macro.camelize(Atom.to_string(name)))}
                      end)

  @container_components (for {name, comp} <- Dala.Ui.Component.components(),
                             comp.category == :container,
                             into: MapSet.new() do
                           name
                         end)

  # Generate screen/2 that parses the block AST and builds entity structs directly.
  # This bypasses the entity macro modules created by Spark's Module.create,
  # which don't work correctly with require/import.
  defmacro screen(opts, do: block) do
    caller_module = __CALLER__.module
    ensure_extensions(caller_module)

    # Validate opts against the screen section schema
    screen_schema = [name: [type: :atom, required: true, doc: "Screen identifier"]]

    validated_opts =
      case Spark.Options.validate(Keyword.new(opts), screen_schema) do
        {:ok, vopts} ->
          vopts

        {:error, error} ->
          raise Spark.Error.DslError,
            module: caller_module,
            message: error,
            path: [:screen]
      end

    # Parse the block AST and build entity structs
    entities = parse_entities(block, caller_module)

    quote do
      # Register this section with Spark DSL state
      current_sections = Process.get({__MODULE__, :spark_sections}, [])

      unless {Dala.Spark.Dsl, [:screen]} in current_sections do
        Process.put({__MODULE__, :spark_sections}, [
          {Dala.Spark.Dsl, [:screen]} | current_sections
        ])
      end

      # Store section opts and entities in DSL state
      current_config =
        Process.get(
          {__MODULE__, :spark, [:screen]},
          Spark.Dsl.Extension.default_section_config()
        )

      Process.put(
        {__MODULE__, :spark, [:screen]},
        %{
          current_config
          | section_anno: nil,
            opts: unquote(Macro.escape(validated_opts)),
            entities: unquote(Macro.escape(entities))
        }
      )
    end
  end

  # Generate attributes/2 that parses the block AST and builds attribute structs.
  defmacro attributes(do: block) do
    caller_module = __CALLER__.module
    ensure_extensions(caller_module)

    # Parse the block AST and build attribute structs
    attributes = parse_attributes(block, caller_module)

    quote do
      # Register this section with Spark DSL state
      current_sections = Process.get({__MODULE__, :spark_sections}, [])

      unless {Dala.Spark.Dsl, [:attributes]} in current_sections do
        Process.put({__MODULE__, :spark_sections}, [
          {Dala.Spark.Dsl, [:attributes]} | current_sections
        ])
      end

      # Store attributes in DSL state
      current_config =
        Process.get(
          {__MODULE__, :spark, [:attributes]},
          Spark.Dsl.Extension.default_section_config()
        )

      Process.put(
        {__MODULE__, :spark, [:attributes]},
        %{
          current_config
          | section_anno: nil,
            entities: unquote(Macro.escape(attributes))
        }
      )
    end
  end

  # ── AST parsing for entity blocks ───────────────────────────────────────

  defp parse_entities(block_ast, caller_module) do
    calls = extract_calls_from_block(block_ast)
    Enum.flat_map(calls, &parse_entity_call(&1, caller_module))
  end

  defp extract_calls_from_block({:__block__, _, calls}), do: calls
  defp extract_calls_from_block(call) when is_tuple(call), do: [call]
  defp extract_calls_from_block(_), do: []

  defp parse_entity_call({name, meta, args}, caller_module) when is_atom(name) do
    component_name = name

    if Map.has_key?(@component_structs, component_name) do
      {children, opts, _block_ast} = extract_children_and_opts(args, component_name)
      struct_module = Map.get(@component_structs, component_name)
      is_container = MapSet.member?(@container_components, component_name)

      parsed_children =
        if is_container and children != [] do
          Enum.flat_map(children, &parse_entity_call(&1, caller_module))
        else
          []
        end

      entity = build_entity_struct(struct_module, component_name, opts, parsed_children, meta)
      [entity]
    else
      []
    end
  end

  defp parse_entity_call(_, _), do: []

  # Extract children (do block) and opts from the macro call arguments.
  # The args AST depends on how the component was called:
  #   text("Hello")               → args = ["Hello"]
  #   text "Hello"                → args = ["Hello"]
  #   text "Hello", text_size: :xl → args = ["Hello", text_size: :xl]
  #   column padding: :md do ... end → args = [padding: :md, do: block]
  #   divider()                   → args = []
  defp extract_children_and_opts(args, component_name) do
    comp = Dala.Ui.Component.get(component_name)
    is_container = MapSet.member?(@container_components, component_name)

    if is_container do
      {opts, block_ast} = extract_container_args(args)
      children = extract_children_from_block(block_ast)
      {children, opts, block_ast}
    else
      # Leaf components are called with positional args + optional keyword opts
      # e.g., text("Hello") or text "Hello", text_size: :xl
      {positional, opts} = extract_leaf_args(args, comp)
      {[], positional ++ opts, nil}
    end
  end

  defp extract_leaf_args(args, comp) do
    # For leaf components, the first prop is the primary content (e.g., text for text component)
    # If the first arg is a string/binary, it goes to the first prop
    case args do
      [first | rest] when is_binary(first) ->
        # First arg is a string (the content), rest are keyword opts
        # Keyword args may be wrapped in an extra list: [on_tap: :increment]
        opts = List.flatten(rest)
        {[{hd(comp.props), first}], opts}

      list when is_list(list) ->
        # All args are keyword opts, flatten in case they're nested
        {[], List.flatten(list)}

      _ ->
        {[], []}
    end
  end

  # Extract opts and block from container component args.
  # Container components are called as:
  #   column padding: :md, gap: :sm do ... end
  # Which produces AST args like:
  #   [[padding: :md, gap: :sm], [do: block_ast]]
  # Or with explicit parentheses:
  #   column(padding: :md) do ... end
  #   args = [padding: :md, do: block_ast]
  defp extract_container_args(args) when is_list(args) do
    # Check if the last element is a [do: block] keyword list
    case List.last(args) do
      [do: block_ast] ->
        # Args are like [[opts...], [do: block]]
        # The first element is the opts list
        opts =
          case List.first(args) do
            opts_list when is_list(opts_list) -> opts_list
            _ -> []
          end

        {opts, block_ast}

      _ ->
        # Args might be like [opts..., do: block] (single flat list)
        case Keyword.pop(args, :do) do
          {nil, _} -> {args, nil}
          {block_ast, opts} -> {opts, block_ast}
        end
    end
  end

  defp extract_container_args(_), do: {[], nil}

  defp extract_children_from_block(nil), do: []
  defp extract_children_from_block({:__block__, _, children}) when is_list(children), do: children
  defp extract_children_from_block(call) when is_tuple(call), do: [call]
  defp extract_children_from_block(_), do: []

  defp build_entity_struct(struct_module, component_name, opts, children, meta) do
    comp = Dala.Ui.Component.get(component_name)
    opts = List.wrap(opts)

    # Build a map of field values from opts
    # For leaf components, opts may contain positional values (strings, etc.)
    # that need to be mapped to the correct struct fields
    field_values =
      Enum.reduce(opts, %{}, fn
        {key, value}, acc when is_atom(key) ->
          Map.put(acc, key, value)

        value, acc when is_binary(value) ->
          # String positional arg goes to the first field
          first_field = hd(comp.props)
          Map.put(acc, first_field, value)

        value, acc when is_atom(value) ->
          # Atom value (e.g., list(:my_list)) — treat as positional
          first_field = hd(comp.props)
          Map.put(acc, first_field, value)

        _, acc ->
          acc
      end)

    # Add children if present
    field_values =
      if children != [] do
        Map.put(field_values, :children, children)
      else
        field_values
      end

    # Add spark metadata
    field_values =
      Map.put(field_values, :__spark_metadata__, %Spark.Dsl.Entity.Meta{
        anno: meta,
        properties_anno: %{}
      })

    struct(struct_module, field_values)
  end

  # ── AST parsing for attribute blocks ────────────────────────────────────

  defp parse_attributes(block_ast, caller_module) do
    calls = extract_calls_from_block(block_ast)
    Enum.flat_map(calls, &parse_attribute_call(&1, caller_module))
  end

  defp parse_attribute_call({:attribute, meta, args}, _caller_module) when length(args) >= 2 do
    [name, type] = Enum.take(args, 2)
    default = if length(args) >= 3, do: Enum.at(args, 2), else: nil

    [
      %Attribute{
        name: name,
        type: type,
        default: default,
        __spark_metadata__: %Spark.Dsl.Entity.Meta{anno: meta, properties_anno: %{}}
      }
    ]
  end

  defp parse_attribute_call(_, _), do: []

  # ── __using__ macro for external consumers ──────────────────────────────

  defmacro __using__(_opts) do
    quote do
      require Dala.Spark.Dsl
      import Dala.Spark.Dsl

      use Spark.Dsl,
        many_extension_kinds: [:extensions],
        default_extensions: [extensions: [Dala.Spark.Dsl]]

      @extensions [Dala.Spark.Dsl]
      @before_compile Spark.Dsl
      @spark_parent Dala.Spark.Dsl
      Module.register_attribute(__MODULE__, :persist, accumulate: true)
      @persist {:module, __MODULE__}
      @persist {:file, __ENV__.file}
      @persist {:extensions, [Dala.Spark.Dsl]}
    end
  end

  # Public helper to ensure @extensions is set on a module.
  def ensure_extensions(module) do
    case Module.get_attribute(module, :extensions) do
      nil ->
        Module.put_attribute(module, :extensions, [__MODULE__])

      _ ->
        :ok
    end
  end

  # ── Verifier ────────────────────────────────────────────────────────────

  defmodule Verifier do
    @moduledoc """
    Compile-time validation for Dala Spark DSL.

    Checks:
    - All event handler props reference atoms
    - Attribute types are valid
    """

    use Spark.Dsl.Verifier

    @event_props [
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

    @valid_attr_types [:integer, :string, :boolean, :float, :atom, :list, :map]

    @impl true
    def verify(dsl_state) do
      attr_errors = verify_attributes(dsl_state)
      entity_errors = verify_entities(dsl_state)

      case attr_errors ++ entity_errors do
        [] -> :ok
        msgs -> {:error, Enum.join(msgs, ";")}
      end
    end

    defp verify_attributes(dsl_state) do
      attributes = Spark.Dsl.Transformer.get_entities(dsl_state, [:attributes])

      Enum.flat_map(attributes, fn attr ->
        type = Map.get(attr, :type)

        if type in @valid_attr_types do
          []
        else
          ["attribute #{inspect(Map.get(attr, :name))} has invalid type: #{inspect(type)}"]
        end
      end)
    end

    defp verify_entities(dsl_state) do
      screen_entities = Spark.Dsl.Transformer.get_entities(dsl_state, [:screen])
      Enum.flat_map(screen_entities, &verify_entity/1)
    end

    defp verify_entity(entity) do
      own_errors =
        Enum.flat_map(@event_props, fn prop ->
          case Map.get(entity, prop) do
            nil ->
              []

            value when is_atom(value) ->
              []

            value ->
              [
                "#{entity.__struct__ |> Module.split() |> List.last()}.#{prop} must be an atom, got: #{inspect(value)}"
              ]
          end
        end)

      child_errors =
        case Map.get(entity, :children) do
          nil -> []
          children -> Enum.flat_map(children, &verify_entity/1)
        end

      own_errors ++ child_errors
    end
  end

  # ── dala/1 macro ────────────────────────────────────────────────────────

  defmacro dala(do: block) do
    block
  end
end
