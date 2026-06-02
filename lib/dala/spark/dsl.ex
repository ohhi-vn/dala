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
  # All UI component structs, @leaf_entities, @all_entities, and individual
  # @component_name module attributes are injected here at compile time.
  use Dala.Spark.Dsl.Entities

  # ── Screen section ──────────────────────────────────────────────────────
  # Holds all entities — both leaf and container.
  # Container entities use `recursive_as: :children` so they nest.

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

  # Generate screen/2 that imports entity modules and executes the block
  defmacro screen(_opts, do: block) do
    entity_imports = generate_entity_imports()
    caller = __CALLER__

    quote do
      # Ensure @extensions is set so entity macros can look it up via
      # Spark.Dsl.Extension.get_attribute/2 at compile time
      Dala.Spark.Dsl.ensure_extensions(unquote(caller.module))
      # Import all entity modules so components are available inside the block
      unquote_splicing(entity_imports)
      # Execute the block
      unquote(block)
    end
  end

  # Generate attributes/2 that imports attribute entity module
  defmacro attributes(do: block) do
    caller = __CALLER__

    quote do
      Dala.Spark.Dsl.ensure_extensions(unquote(caller.module))
      import Dala.Spark.Dsl.Attributes.Attribute
      unquote(block)
    end
  end

  # Helper to generate import statements for all entity modules
  defp generate_entity_imports do
    Dala.Ui.Component.components()
    |> Enum.map(fn {_name, comp} ->
      mod =
        Module.concat(Dala.Spark.Dsl.Screen, comp.name |> Atom.to_string() |> Macro.camelize())

      quote do: import(unquote(mod))
    end)
  end

  # ── __using__ macro for external consumers ──────────────────────────────

  defmacro __using__(_opts) do
    quote do
      require Dala.Spark.Dsl
      import Dala.Spark.Dsl

      use Spark.Dsl,
        many_extension_kinds: [:extensions],
        default_extensions: [extensions: [Dala.Spark.Dsl]]
    end
  end

  # Public helper to ensure @extensions is set on a module.
  # This is needed because Spark.Dsl's inner __using__ macro only sets
  # @extensions when :elixir_module.mode == :all, which may not always
  # be the case during macro expansion.
  def ensure_extensions(module) do
    case Module.get_attribute(module, :extensions) do
      nil ->
        Module.put_attribute(module, :extensions, [__MODULE__])

      _ ->
        :ok
    end
  end

  # ── Custom screen macro for top-level section ──────────────────────────
  # Spark's build_section skips defining the section macro for top-level
  # sections. We define it here manually to support the
  # `screen name: :foo do ... end` calling convention.

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
