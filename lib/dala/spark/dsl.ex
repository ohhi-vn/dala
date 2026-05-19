defmodule Dala.Spark.Dsl do
  @moduledoc """
  Spark DSL for declarative Dala screens.

  Defines attributes for screen state and UI component entities that mirror
  `Dala.Ui.Widgets` one-to-one. Container entities (`column`, `row`, `box`, `scroll`,
  `modal`, `pressable`, `safe_area`) support nested children via Spark's
  `entities` + `recursive_as` mechanism.

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
    entities: [@attribute]
  }

  # ── UI component entities ───────────────────────────────────────────────
  # All entities that can appear as children of containers or directly in
  # a screen block. Container entities list these under `entities` and use
  # `recursive_as: :children` so they can nest inside each other.

  # -- Leaf nodes (no children) -------------------------------------------

  defmodule Text do
    @moduledoc false
    defstruct text: nil,
              text_color: nil,
              text_size: nil,
              font_weight: nil,
              font_family: nil,
              text_align: nil,
              italic: nil,
              line_height: nil,
              letter_spacing: nil,
              padding: nil,
              padding_top: nil,
              padding_right: nil,
              padding_bottom: nil,
              padding_left: nil,
              background: nil,
              corner_radius: nil,
              fill_width: nil,
              on_tap: nil,
              on_long_press: nil,
              on_double_tap: nil,
              accessibility_id: nil,
              __spark_metadata__: nil
  end

  @text %Spark.Dsl.Entity{
    name: :text,
    target: Text,
    describe: "Display text",
    args: [:text],
    examples: [
      "text \"Hello, world!\"",
      "text \"Count: @count\", text_size: :xl, text_color: :on_surface"
    ],
    schema: [
      text: [type: :string, required: true, doc: "Text content (supports @ref syntax)"],
      text_color: [type: :any, doc: "Text color token"],
      text_size: [type: :any, doc: "Font size (integer or token like :xl)"],
      font_weight: [
        type: {:one_of, ["regular", "medium", "semibold", "bold", "light", "thin"]},
        doc: "Font weight"
      ],
      font_family: [type: :string, doc: "Custom font family name"],
      text_align: [type: {:one_of, [:left, :center, :right]}, doc: "Text alignment"],
      italic: [type: :boolean, doc: "Italic style"],
      line_height: [type: :float, doc: "Line height multiplier (e.g. 1.5)"],
      letter_spacing: [type: :float, doc: "Extra letter spacing in pt"],
      padding: [type: :any, doc: "Padding (token or integer)"],
      padding_top: [type: :any, doc: "Top padding"],
      padding_right: [type: :any, doc: "Right padding"],
      padding_bottom: [type: :any, doc: "Bottom padding"],
      padding_left: [type: :any, doc: "Left padding"],
      background: [type: :any, doc: "Background color token"],
      corner_radius: [type: :integer, doc: "Rounded corner radius"],
      fill_width: [type: :boolean, doc: "Stretch to fill parent width"],
      on_tap: [type: :atom, doc: "Event handler for tap"],
      on_long_press: [type: :atom, doc: "Event handler for long press"],
      on_double_tap: [type: :atom, doc: "Event handler for double tap"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- Button -------------------------------------------------------------

  defmodule Button do
    @moduledoc false
    defstruct text: nil,
              on_tap: nil,
              disabled: nil,
              text_color: nil,
              text_size: nil,
              font_weight: nil,
              background: nil,
              padding: nil,
              padding_top: nil,
              padding_right: nil,
              padding_bottom: nil,
              padding_left: nil,
              corner_radius: nil,
              fill_width: nil,
              accessibility_id: nil,
              __spark_metadata__: nil
  end

  @button %Spark.Dsl.Entity{
    name: :button,
    target: Button,
    describe: "Tappable button",
    args: [:text],
    examples: [
      "button \"Press me\", on_tap: :pressed",
      "button \"Submit\", on_tap: :submit, background: :primary, text_color: :on_primary"
    ],
    schema: [
      text: [type: :string, required: true, doc: "Button label (supports @ref syntax)"],
      on_tap: [type: :atom, doc: "Event handler for tap"],
      disabled: [type: :boolean, doc: "Disable the button"],
      text_color: [type: :any, doc: "Label color token"],
      text_size: [type: :any, doc: "Font size"],
      font_weight: [
        type: {:one_of, ["regular", "medium", "semibold", "bold", "light", "thin"]},
        doc: "Font weight"
      ],
      background: [type: :any, doc: "Background color token"],
      padding: [type: :any, doc: "Padding"],
      padding_top: [type: :any, doc: "Top padding"],
      padding_right: [type: :any, doc: "Right padding"],
      padding_bottom: [type: :any, doc: "Bottom padding"],
      padding_left: [type: :any, doc: "Left padding"],
      corner_radius: [type: :integer, doc: "Rounded corner radius"],
      fill_width: [type: :boolean, doc: "Stretch to fill parent width"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- Icon ---------------------------------------------------------------

  defmodule Icon do
    @moduledoc false
    defstruct name: nil,
              text_size: nil,
              text_color: nil,
              padding: nil,
              background: nil,
              on_tap: nil,
              on_long_press: nil,
              accessibility_id: nil,
              __spark_metadata__: nil
  end

  @icon %Spark.Dsl.Entity{
    name: :icon,
    target: Icon,
    describe: "Platform-native icon (SF Symbols on iOS, Material on Android)",
    args: [:name],
    examples: [
      "icon \"settings\", text_size: 24, text_color: :on_surface",
      "icon \"chevron_right\", on_tap: :navigate"
    ],
    schema: [
      name: [type: :string, required: true, doc: "Icon name or raw identifier"],
      text_size: [type: :any, doc: "Glyph size in sp"],
      text_color: [type: :any, doc: "Glyph tint color token"],
      padding: [type: :any, doc: "Padding"],
      background: [type: :any, doc: "Background color token"],
      on_tap: [type: :atom, doc: "Event handler for tap"],
      on_long_press: [type: :atom, doc: "Event handler for long press"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- Divider ------------------------------------------------------------

  defmodule Divider do
    @moduledoc false
    defstruct thickness: nil, color: nil, padding: nil, __spark_metadata__: nil
  end

  @divider %Spark.Dsl.Entity{
    name: :divider,
    target: Divider,
    describe: "Horizontal or vertical divider line",
    examples: ["divider()", "divider thickness: 2, color: :primary"],
    schema: [
      thickness: [type: :float, doc: "Line thickness in pt (default: 1.0)"],
      color: [type: :any, doc: "Divider color token (default: :border)"],
      padding: [type: :any, doc: "Padding around the divider"]
    ]
  }

  # -- Spacer -------------------------------------------------------------

  defmodule Spacer do
    @moduledoc false
    defstruct size: nil, __spark_metadata__: nil
  end

  @spacer %Spark.Dsl.Entity{
    name: :spacer,
    target: Spacer,
    describe: "Flexible or fixed space",
    examples: ["spacer()", "spacer size: 20"],
    schema: [
      size: [type: :integer, doc: "Fixed size in pt (omit for flexible spacer)"]
    ]
  }

  # -- TextField ----------------------------------------------------------

  defmodule TextField do
    @moduledoc false
    defstruct text: nil,
              placeholder: nil,
              on_change: nil,
              on_focus: nil,
              on_blur: nil,
              on_submit: nil,
              on_compose: nil,
              keyboard_type: nil,
              return_key: nil,
              text_color: nil,
              text_size: nil,
              background: nil,
              padding: nil,
              corner_radius: nil,
              accessibility_id: nil,
              __spark_metadata__: nil
  end

  @text_field %Spark.Dsl.Entity{
    name: :text_field,
    target: TextField,
    describe: "Single-line text input",
    examples: [
      "text_field placeholder: \"Enter name\", on_change: :name_changed",
      "text_field keyboard_type: :email, return_key: :next, on_submit: :next_field"
    ],
    schema: [
      text: [type: :string, doc: "Initial/current text value"],
      placeholder: [type: :string, doc: "Placeholder text when empty"],
      on_change: [type: :atom, doc: "Event handler for text changes"],
      on_focus: [type: :atom, doc: "Event handler when field gains focus"],
      on_blur: [type: :atom, doc: "Event handler when field loses focus"],
      on_submit: [type: :atom, doc: "Event handler when return key is pressed"],
      on_compose: [type: :atom, doc: "Event handler for IME composition events"],
      keyboard_type: [
        type: {:one_of, [:default, :number, :decimal, :email, :phone, :url]},
        doc: "Keyboard type"
      ],
      return_key: [
        type: {:one_of, [:done, :next, :go, :search, :send]},
        doc: "Return key type"
      ],
      text_color: [type: :any, doc: "Text color token"],
      text_size: [type: :any, doc: "Font size"],
      background: [type: :any, doc: "Background color token"],
      padding: [type: :any, doc: "Padding"],
      corner_radius: [type: :integer, doc: "Rounded corner radius"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- Toggle -------------------------------------------------------------

  defmodule Toggle do
    @moduledoc false
    defstruct value: nil,
              on_change: nil,
              text: nil,
              track_color: nil,
              thumb_color: nil,
              accessibility_id: nil,
              __spark_metadata__: nil
  end

  @toggle %Spark.Dsl.Entity{
    name: :toggle,
    target: Toggle,
    describe: "Boolean toggle switch (prefer over switch for new code)",
    examples: [
      "toggle value: true, on_change: :notifications_toggled, text: \"Notifications\""
    ],
    schema: [
      value: [type: :boolean, doc: "On/off state"],
      on_change: [type: :atom, doc: "Event handler for value changes"],
      text: [type: :string, doc: "Optional label text beside the switch"],
      track_color: [type: :any, doc: "Track color when on"],
      thumb_color: [type: :any, doc: "Thumb color"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- Slider -------------------------------------------------------------

  defmodule Slider do
    @moduledoc false
    defstruct value: nil,
              min_value: nil,
              max_value: nil,
              on_change: nil,
              color: nil,
              accessibility_id: nil,
              __spark_metadata__: nil
  end

  @slider %Spark.Dsl.Entity{
    name: :slider,
    target: Slider,
    describe: "Continuous range slider",
    examples: [
      "slider value: 0.5, min_value: 0, max_value: 100, on_change: :volume_changed"
    ],
    schema: [
      value: [type: :float, doc: "Current value"],
      min_value: [type: :float, doc: "Minimum value (default: 0.0)"],
      max_value: [type: :float, doc: "Maximum value (default: 1.0)"],
      on_change: [type: :atom, doc: "Event handler for value changes"],
      color: [type: :any, doc: "Slider tint color token"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- Switch (legacy) ----------------------------------------------------

  defmodule Switch do
    @moduledoc false
    defstruct value: nil,
              on_toggle: nil,
              text: nil,
              track_color: nil,
              thumb_color: nil,
              accessibility_id: nil,
              __spark_metadata__: nil
  end

  @switch %Spark.Dsl.Entity{
    name: :switch,
    target: Switch,
    describe: "Boolean toggle switch (legacy — prefer toggle for new code)",
    examples: ["switch value: true, on_toggle: :toggled"],
    schema: [
      value: [type: :boolean, doc: "On/off state"],
      on_toggle: [type: :atom, doc: "Event handler for toggle"],
      text: [type: :string, doc: "Label text displayed beside the switch"],
      track_color: [type: :any, doc: "Track color when on"],
      thumb_color: [type: :any, doc: "Thumb color"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- Image --------------------------------------------------------------

  defmodule Image do
    @moduledoc false
    defstruct src: nil,
              resize_mode: nil,
              width: nil,
              height: nil,
              corner_radius: nil,
              placeholder_color: nil,
              accessibility_id: nil,
              __spark_metadata__: nil
  end

  @image %Spark.Dsl.Entity{
    name: :image,
    target: Image,
    describe: "Display image from URL or local asset",
    args: [:src],
    examples: [
      "image \"https://example.com/photo.jpg\"",
      "image \"logo.png\", width: 100, height: 100, resize_mode: :contain"
    ],
    schema: [
      src: [type: :string, required: true, doc: "URL or local asset name"],
      resize_mode: [
        type: {:one_of, [:cover, :contain, :stretch, :repeat]},
        doc: "Resize mode (default: :cover)"
      ],
      width: [type: :integer, doc: "Width in dp/pts"],
      height: [type: :integer, doc: "Height in dp/pts"],
      corner_radius: [type: :integer, doc: "Rounded corner radius"],
      placeholder_color: [type: :any, doc: "Color shown while loading"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- Video --------------------------------------------------------------

  defmodule Video do
    @moduledoc false
    defstruct src: nil,
              autoplay: nil,
              loop: nil,
              controls: nil,
              width: nil,
              height: nil,
              __spark_metadata__: nil
  end

  @video %Spark.Dsl.Entity{
    name: :video,
    target: Video,
    describe: "Inline video player",
    args: [:src],
    examples: ["video \"https://example.com/clip.mp4\", autoplay: true, loop: true"],
    schema: [
      src: [type: :string, required: true, doc: "Video URL"],
      autoplay: [type: :boolean, doc: "Start playing immediately"],
      loop: [type: :boolean, doc: "Loop playback"],
      controls: [type: :boolean, doc: "Show playback controls (default: true)"],
      width: [type: :integer, doc: "Width in dp/pts"],
      height: [type: :integer, doc: "Height in dp/pts"]
    ]
  }

  # -- ActivityIndicator --------------------------------------------------

  defmodule ActivityIndicator do
    @moduledoc false
    defstruct size: nil, color: nil, animating: nil, __spark_metadata__: nil
  end

  @activity_indicator %Spark.Dsl.Entity{
    name: :activity_indicator,
    target: ActivityIndicator,
    describe: "Loading spinner",
    examples: ["activity_indicator size: :large, color: :primary"],
    schema: [
      size: [type: {:one_of, [:small, :large]}, doc: "Spinner size (default: :small)"],
      color: [type: :any, doc: "Spinner color token"],
      animating: [type: :boolean, doc: "Whether animating (default: true)"]
    ]
  }

  # -- ProgressBar --------------------------------------------------------

  defmodule ProgressBar do
    @moduledoc false
    defstruct progress: nil, indeterminate: nil, color: nil, __spark_metadata__: nil
  end

  @progress_bar %Spark.Dsl.Entity{
    name: :progress_bar,
    target: ProgressBar,
    describe: "Progress bar",
    examples: ["progress_bar progress: 0.7, color: :primary"],
    schema: [
      progress: [type: :float, doc: "Progress 0.0–1.0"],
      indeterminate: [type: :boolean, doc: "Show indeterminate spinner"],
      color: [type: :any, doc: "Progress bar color token"]
    ]
  }

  # -- StatusBar ----------------------------------------------------------

  defmodule StatusBar do
    @moduledoc false
    defstruct bar_style: nil, hidden: nil, __spark_metadata__: nil
  end

  @status_bar %Spark.Dsl.Entity{
    name: :status_bar,
    target: StatusBar,
    describe: "Status bar appearance control",
    examples: ["status_bar bar_style: :light_content, hidden: false"],
    schema: [
      bar_style: [
        type: {:one_of, [:default, :light_content]},
        doc: "Status bar style"
      ],
      hidden: [type: :boolean, doc: "Hide the status bar"]
    ]
  }

  # -- RefreshControl -----------------------------------------------------

  defmodule RefreshControl do
    @moduledoc false
    defstruct on_refresh: nil, refreshing: nil, tint_color: nil, __spark_metadata__: nil
  end

  @refresh_control %Spark.Dsl.Entity{
    name: :refresh_control,
    target: RefreshControl,
    describe: "Pull-to-refresh control",
    examples: ["refresh_control on_refresh: :reload, refreshing: false"],
    schema: [
      on_refresh: [type: :atom, doc: "Event handler for pull-to-refresh"],
      refreshing: [type: :boolean, doc: "Whether refresh is in progress"],
      tint_color: [type: :any, doc: "Spinner tint color token"]
    ]
  }

  # -- WebView ------------------------------------------------------------

  defmodule WebView do
    @moduledoc false
    defstruct url: nil,
              allow: nil,
              show_url: nil,
              title: nil,
              width: nil,
              height: nil,
              __spark_metadata__: nil
  end

  @webview %Spark.Dsl.Entity{
    name: :webview,
    target: WebView,
    describe: "Native web view with JS bridge",
    args: [:url],
    examples: [
      "webview \"https://elixir-lang.org\"",
      "webview \"https://example.com\", show_url: true, width: 400, height: 600"
    ],
    schema: [
      url: [type: :string, required: true, doc: "URL to load"],
      allow: [type: {:list, :string}, doc: "Allowed URL prefixes for navigation"],
      show_url: [type: :boolean, doc: "Show URL label above the WebView"],
      title: [type: :string, doc: "Static title label (overrides show_url)"],
      width: [type: :integer, doc: "Width in dp/pts"],
      height: [type: :integer, doc: "Height in dp/pts"]
    ]
  }

  # -- CameraPreview ------------------------------------------------------

  defmodule CameraPreview do
    @moduledoc false
    defstruct facing: nil, width: nil, height: nil, __spark_metadata__: nil
  end

  @camera_preview %Spark.Dsl.Entity{
    name: :camera_preview,
    target: CameraPreview,
    describe: "Live camera feed",
    examples: ["camera_preview facing: :front, width: 300, height: 400"],
    schema: [
      facing: [type: {:one_of, [:back, :front]}, doc: "Camera facing (default: :back)"],
      width: [type: :integer, doc: "Width in dp/pts"],
      height: [type: :integer, doc: "Height in dp/pts"]
    ]
  }

  # -- NativeView ---------------------------------------------------------

  defmodule NativeView do
    @moduledoc false
    defstruct module: nil, id: nil, __spark_metadata__: nil
  end

  @native_view %Spark.Dsl.Entity{
    name: :native_view,
    target: NativeView,
    describe: "Platform-native component (must implement Dala.Ui.NativeView)",
    args: [:module],
    examples: ["native_view MyApp.ChartComponent, id: :revenue_chart"],
    schema: [
      module: [
        type: :atom,
        required: true,
        doc: "Component module (implements Dala.Ui.NativeView)"
      ],
      id: [type: :atom, required: true, doc: "Unique identifier per screen"]
    ]
  }

  # -- TabBar -------------------------------------------------------------

  defmodule TabBar do
    @moduledoc false
    defstruct tabs: nil,
              active_tab: nil,
              on_tab_select: nil,
              accessibility_id: nil,
              __spark_metadata__: nil
  end

  @tab_bar %Spark.Dsl.Entity{
    name: :tab_bar,
    target: TabBar,
    describe: "Tab navigation bar",
    examples: [
      "tab_bar tabs: [%{id: \"home\", label: \"Home\", icon: \"home\"}], active_tab: \"home\", on_tab_select: :tab_changed"
    ],
    schema: [
      tabs: [type: :any, doc: "List of tab definitions (%{id, label, icon?})"],
      active_tab: [type: :string, doc: "Currently selected tab id"],
      on_tab_select: [type: :atom, doc: "Event handler for tab selection"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- List ---------------------------------------------------------------

  defmodule DalaList do
    @moduledoc false
    defstruct id: nil,
              data: nil,
              on_end_reached: nil,
              scroll: nil,
              accessibility_id: nil,
              __spark_metadata__: nil
  end

  @list %Spark.Dsl.Entity{
    name: :list,
    target: DalaList,
    describe: "Data-driven list (FlatList equivalent)",
    args: [:id],
    examples: [
      "list :my_list, data: @items, on_end_reached: :load_more"
    ],
    schema: [
      id: [type: :atom, required: true, doc: "List identifier for selection events"],
      data: [type: :any, doc: "Enumerable of items (supports @ref syntax)"],
      on_end_reached: [type: :atom, doc: "Event handler when list reaches end"],
      scroll: [type: :boolean, doc: "Enable scrolling (default: true)"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }


  # -- Checkbox -----------------------------------------------------------

  defmodule Checkbox do
    @moduledoc false
    defstruct value: nil,
              on_change: nil,
              label: nil,
              disabled: nil,
              text_color: nil,
              text_size: nil,
              accessibility_id: nil,
              __spark_metadata__: nil
  end

  @checkbox %Spark.Dsl.Entity{
    name: :checkbox,
    target: Checkbox,
    describe: "Checkbox input",
    examples: ["checkbox value: true, on_change: :agree_toggled, label: \"I agree\""],
    schema: [
      value: [type: :boolean, doc: "Checked state"],
      on_change: [type: :atom, doc: "Event handler for value changes"],
      label: [type: :string, doc: "Label text beside the checkbox"],
      disabled: [type: :boolean, doc: "Disable the checkbox"],
      text_color: [type: :any, doc: "Text color token"],
      text_size: [type: :any, doc: "Font size"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- Radio --------------------------------------------------------------

  defmodule Radio do
    @moduledoc false
    defstruct selected: nil,
              on_select: nil,
              label: nil,
              group: nil,
              disabled: nil,
              text_color: nil,
              text_size: nil,
              accessibility_id: nil,
              __spark_metadata__: nil
  end

  @radio %Spark.Dsl.Entity{
    name: :radio,
    target: Radio,
    describe: "Radio button",
    examples: ["radio selected: true, on_select: :option_a, label: \"Option A\", group: \"choices\""],
    schema: [
      selected: [type: :boolean, doc: "Whether this radio is selected"],
      on_select: [type: :atom, doc: "Event handler when selected"],
      label: [type: :string, doc: "Label text beside the radio"],
      group: [type: :string, doc: "Radio group name (mutually exclusive within group)"],
      disabled: [type: :boolean, doc: "Disable the radio"],
      text_color: [type: :any, doc: "Text color token"],
      text_size: [type: :any, doc: "Font size"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- Chip ---------------------------------------------------------------

  defmodule Chip do
    @moduledoc false
    defstruct label: nil, variant: nil, selected: nil, on_tap: nil, icon: nil,
              on_remove: nil, disabled: nil, enabled: nil, text_color: nil,
              text_size: nil, background: nil, corner_radius: nil,
              accessibility_id: nil, __spark_metadata__: nil
  end

  @chip %Spark.Dsl.Entity{
    name: :chip,
    target: Chip,
    describe: "Chip/tag component",
    examples: ["chip label: \"Filter\", variant: :filter, selected: true, on_tap: :chip_tapped"],
    schema: [
      label: [type: :string, doc: "Chip text"],
      variant: [type: {:one_of, [:assist, :filter, :input, :suggestion]}, doc: "Chip variant"],
      selected: [type: :boolean, doc: "Selected state (for filter chips)"],
      on_tap: [type: :atom, doc: "Event handler for tap"],
      icon: [type: :string, doc: "Icon name displayed before the label"],
      on_remove: [type: :atom, doc: "Event handler when remove icon is tapped"],
      disabled: [type: :boolean, doc: "Disable the chip"],
      enabled: [type: :boolean, doc: "Whether the chip is interactive"],
      text_color: [type: :any, doc: "Text color token"],
      text_size: [type: :any, doc: "Font size"],
      background: [type: :any, doc: "Background color token"],
      corner_radius: [type: :integer, doc: "Rounded corner radius"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- Snackbar -----------------------------------------------------------

  defmodule Snackbar do
    @moduledoc false
    defstruct message: nil, action_label: nil, on_action: nil, duration: nil,
              visible: nil, text_color: nil, background: nil,
              accessibility_id: nil, __spark_metadata__: nil
  end

  @snackbar %Spark.Dsl.Entity{
    name: :snackbar,
    target: Snackbar,
    describe: "Snackbar/toast notification",
    examples: ["snackbar message: \"Item deleted\", action_label: \"Undo\", on_action: :undo"],
    schema: [
      message: [type: :string, doc: "The message text"],
      action_label: [type: :string, doc: "Label for the optional action button"],
      on_action: [type: :atom, doc: "Event handler when action button is tapped"],
      duration: [type: {:one_of, [:short, :long]}, doc: "Display duration"],
      visible: [type: :boolean, doc: "Whether the snackbar is shown"],
      text_color: [type: :any, doc: "Text color token"],
      background: [type: :any, doc: "Background color token"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- Fab ----------------------------------------------------------------

  defmodule Fab do
    @moduledoc false
    defstruct icon: nil, text: nil, on_tap: nil, background: nil, color: nil,
              text_color: nil, elevation: nil, corner_radius: nil,
              accessibility_id: nil, __spark_metadata__: nil
  end

  @fab %Spark.Dsl.Entity{
    name: :fab,
    target: Fab,
    describe: "Floating action button",
    examples: ["fab icon: \"edit\", text: \"Compose\", on_tap: :compose"],
    schema: [
      icon: [type: :string, doc: "Icon name"],
      text: [type: :string, doc: "Optional label for extended FAB"],
      on_tap: [type: :atom, doc: "Event handler for tap"],
      background: [type: :any, doc: "Background color token"],
      color: [type: :any, doc: "Icon color token"],
      text_color: [type: :any, doc: "Text color token"],
      elevation: [type: :float, doc: "Shadow depth"],
      corner_radius: [type: :integer, doc: "Rounded corner radius"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- IconButton ---------------------------------------------------------

  defmodule IconButton do
    @moduledoc false
    defstruct icon: nil, on_tap: nil, selected: nil, enabled: nil, color: nil,
              text_color: nil, background: nil, size: nil, disabled: nil,
              accessibility_id: nil, __spark_metadata__: nil
  end

  @icon_button %Spark.Dsl.Entity{
    name: :icon_button,
    target: IconButton,
    describe: "Icon-only button",
    examples: ["icon_button icon: \"favorite\", on_tap: :favorite_tapped"],
    schema: [
      icon: [type: :string, doc: "Icon name"],
      on_tap: [type: :atom, doc: "Event handler for tap"],
      selected: [type: :boolean, doc: "Toggle state for toggle icon buttons"],
      enabled: [type: :boolean, doc: "Whether the button is interactive"],
      color: [type: :any, doc: "Icon color token"],
      text_color: [type: :any, doc: "Text color token"],
      background: [type: :any, doc: "Background color token"],
      size: [type: :any, doc: "Button size"],
      disabled: [type: :boolean, doc: "Disable the button"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- SegmentedButton ---------------------------------------------------

  defmodule SegmentedButton do
    @moduledoc false
    defstruct segments: nil, selected: nil, on_select: nil, text_color: nil,
              background: nil, accessibility_id: nil, __spark_metadata__: nil
  end

  @segmented_button %Spark.Dsl.Entity{
    name: :segmented_button,
    target: SegmentedButton,
    describe: "Segmented button control",
    examples: ["segmented_button segments: [%{id: \"day\", label: \"Day\"}, %{id: \"week\", label: \"Week\"}], selected: \"week\", on_select: :range_changed"],
    schema: [
      segments: [type: :any, doc: "List of segment definitions (%{id, label, icon?})"],
      selected: [type: :string, doc: "Id of the currently selected segment"],
      on_select: [type: :atom, doc: "Event handler for segment selection"],
      text_color: [type: :any, doc: "Text color token"],
      background: [type: :any, doc: "Background color token"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- AppBar -------------------------------------------------------------

  defmodule AppBar do
    @moduledoc false
    defstruct title: nil, leading_icon: nil, on_leading: nil, trailing_actions: nil,
              text_color: nil, background: nil, elevation: nil,
              accessibility_id: nil, __spark_metadata__: nil
  end

  @app_bar %Spark.Dsl.Entity{
    name: :app_bar,
    target: AppBar,
    describe: "Top app bar",
    examples: ["app_bar title: \"My App\", leading_icon: \"back\", on_leading: :back_pressed, trailing_actions: [%{icon: \"search\", on_tap: :search}]"],
    schema: [
      title: [type: :string, doc: "App bar title"],
      leading_icon: [type: :string, doc: "Icon name for the leading navigation icon"],
      on_leading: [type: :atom, doc: "Event handler when leading icon is tapped"],
      trailing_actions: [type: :any, doc: "List of maps with :icon and :on_tap"],
      text_color: [type: :any, doc: "Title and icon color token"],
      background: [type: :any, doc: "Background color token"],
      elevation: [type: :float, doc: "Shadow depth"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- NavBar -------------------------------------------------------------

  defmodule NavBar do
    @moduledoc false
    defstruct items: nil, active: nil, on_select: nil, text_color: nil,
              background: nil, accessibility_id: nil, __spark_metadata__: nil
  end

  @nav_bar %Spark.Dsl.Entity{
    name: :nav_bar,
    target: NavBar,
    describe: "Bottom navigation bar",
    examples: ["nav_bar items: [%{id: \"home\", label: \"Home\", icon: \"home\"}], active: \"home\", on_select: :tab_changed"],
    schema: [
      items: [type: :any, doc: "List of nav item definitions (%{id, label, icon})"],
      active: [type: :string, doc: "Id of the currently active item"],
      on_select: [type: :atom, doc: "Event handler for item selection"],
      text_color: [type: :any, doc: "Text color token"],
      background: [type: :any, doc: "Background color token"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- NavDrawer ----------------------------------------------------------

  defmodule NavDrawer do
    @moduledoc false
    defstruct visible: nil, on_dismiss: nil, items: nil, active: nil, on_select: nil,
              header: nil, background: nil, accessibility_id: nil, __spark_metadata__: nil
  end

  @nav_drawer %Spark.Dsl.Entity{
    name: :nav_drawer,
    target: NavDrawer,
    describe: "Navigation drawer",
    examples: ["nav_drawer visible: true, on_dismiss: :drawer_dismissed, items: [%{id: \"home\", label: \"Home\", icon: \"home\"}], active: \"home\", on_select: :nav_changed"],
    schema: [
      visible: [type: :boolean, doc: "Whether the drawer is shown"],
      on_dismiss: [type: :atom, doc: "Event handler when drawer is dismissed"],
      items: [type: :any, doc: "List of nav item definitions (%{id, label, icon})"],
      active: [type: :string, doc: "Id of the currently active item"],
      on_select: [type: :atom, doc: "Event handler for item selection"],
      header: [type: :string, doc: "Optional header text"],
      background: [type: :any, doc: "Background color token"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- NavRail ------------------------------------------------------------

  defmodule NavRail do
    @moduledoc false
    defstruct items: nil, active: nil, on_select: nil, text_color: nil,
              background: nil, accessibility_id: nil, __spark_metadata__: nil
  end

  @nav_rail %Spark.Dsl.Entity{
    name: :nav_rail,
    target: NavRail,
    describe: "Navigation rail (side navigation)",
    examples: ["nav_rail items: [%{id: \"home\", label: \"Home\", icon: \"home\"}], active: \"home\", on_select: :rail_changed"],
    schema: [
      items: [type: :any, doc: "List of nav item definitions (%{id, label, icon})"],
      active: [type: :string, doc: "Id of the currently active item"],
      on_select: [type: :atom, doc: "Event handler for item selection"],
      text_color: [type: :any, doc: "Text color token"],
      background: [type: :any, doc: "Background color token"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- Menu ---------------------------------------------------------------

  defmodule Menu do
    @moduledoc false
    defstruct items: nil, visible: nil, on_select: nil, text_color: nil,
              background: nil, accessibility_id: nil, __spark_metadata__: nil
  end

  @menu %Spark.Dsl.Entity{
    name: :menu,
    target: Menu,
    describe: "Dropdown menu",
    examples: ["menu items: [%{label: \"Edit\", action: :edit}, %{label: \"Delete\", action: :delete}], visible: true, on_select: :menu_selected"],
    schema: [
      items: [type: :any, doc: "List of menu items (%{label, action, icon?})"],
      visible: [type: :boolean, doc: "Whether the menu is shown"],
      on_select: [type: :atom, doc: "Event handler for item selection"],
      text_color: [type: :any, doc: "Text color token"],
      background: [type: :any, doc: "Background color token"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- DatePicker ---------------------------------------------------------

  defmodule DatePicker do
    @moduledoc false
    defstruct visible: nil, on_select: nil, on_dismiss: nil, selected_date: nil,
              min_date: nil, max_date: nil, title: nil,
              accessibility_id: nil, __spark_metadata__: nil
  end

  @date_picker %Spark.Dsl.Entity{
    name: :date_picker,
    target: DatePicker,
    describe: "Date picker",
    examples: ["date_picker visible: true, on_select: :date_picked, selected_date: \"2025-01-15\""],
    schema: [
      visible: [type: :boolean, doc: "Whether the picker is shown"],
      on_select: [type: :atom, doc: "Event handler with selected date string (ISO 8601)"],
      on_dismiss: [type: :atom, doc: "Event handler when picker is dismissed"],
      selected_date: [type: :string, doc: "Initial date in ISO 8601 format"],
      min_date: [type: :string, doc: "Earliest selectable date"],
      max_date: [type: :string, doc: "Latest selectable date"],
      title: [type: :string, doc: "Optional title text"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- TimePicker ---------------------------------------------------------

  defmodule TimePicker do
    @moduledoc false
    defstruct visible: nil, on_select: nil, on_dismiss: nil, selected_time: nil,
              title: nil, accessibility_id: nil, __spark_metadata__: nil
  end

  @time_picker %Spark.Dsl.Entity{
    name: :time_picker,
    target: TimePicker,
    describe: "Time picker",
    examples: ["time_picker visible: true, on_select: :time_picked, selected_time: \"09:30\""],
    schema: [
      visible: [type: :boolean, doc: "Whether the picker is shown"],
      on_select: [type: :atom, doc: "Event handler with selected time string (HH:MM)"],
      on_dismiss: [type: :atom, doc: "Event handler when picker is dismissed"],
      selected_time: [type: :string, doc: "Initial time in HH:MM format"],
      title: [type: :string, doc: "Optional title text"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- SearchBar ----------------------------------------------------------

  defmodule SearchBar do
    @moduledoc false
    defstruct placeholder: nil, text: nil, on_change: nil, on_submit: nil,
              on_focus: nil, active: nil, on_tap: nil, value: nil,
              text_color: nil, background: nil, corner_radius: nil,
              accessibility_id: nil, __spark_metadata__: nil
  end

  @search_bar %Spark.Dsl.Entity{
    name: :search_bar,
    target: SearchBar,
    describe: "Search bar",
    examples: ["search_bar placeholder: \"Search...\", on_change: :search_changed, on_submit: :search_submitted"],
    schema: [
      placeholder: [type: :string, doc: "Placeholder text when empty"],
      text: [type: :string, doc: "Current search text"],
      on_change: [type: :atom, doc: "Event handler for text changes"],
      on_submit: [type: :atom, doc: "Event handler when search is submitted"],
      on_focus: [type: :atom, doc: "Event handler when bar gains focus"],
      active: [type: :boolean, doc: "Whether the search bar is in active/expanded state"],
      on_tap: [type: :atom, doc: "Event handler when the search bar is tapped"],
      value: [type: :string, doc: "Current search value"],
      text_color: [type: :any, doc: "Text color token"],
      background: [type: :any, doc: "Background color token"],
      corner_radius: [type: :integer, doc: "Rounded corner radius"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- Carousel -----------------------------------------------------------

  defmodule Carousel do
    @moduledoc false
    defstruct id: nil, items: nil, data: nil, on_page_change: nil, loop: nil,
              autoplay: nil, autoplay_interval: nil, peek: nil,
              accessibility_id: nil, __spark_metadata__: nil
  end

  @carousel %Spark.Dsl.Entity{
    name: :carousel,
    target: Carousel,
    describe: "Carousel/slideshow component",
    args: [:id],
    examples: ["carousel :my_carousel, items: @slides, on_page_change: :page_changed"],
    schema: [
      id: [type: :atom, required: true, doc: "Carousel identifier"],
      items: [type: :any, doc: "List of items to render"],
      data: [type: :any, doc: "Enumerable of items (supports @ref syntax)"],
      on_page_change: [type: :atom, doc: "Event handler with new page index on swipe"],
      loop: [type: :boolean, doc: "Enable infinite looping"],
      autoplay: [type: :boolean, doc: "Enable autoplay"],
      autoplay_interval: [type: :integer, doc: "Autoplay interval in ms"],
      peek: [type: :float, doc: "Peek width for adjacent items"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }


  # These use `entities` + `recursive_as: :children` so they can nest
  # inside each other. The `children` field on the target struct holds
  # the list of nested entities.

  # All leaf entities that can appear as children of any container.
  @leaf_entities [
    @text,
    @button,
    @icon,
    @divider,
    @spacer,
    @text_field,
    @toggle,
    @slider,
    @switch,
    @image,
    @video,
    @activity_indicator,
    @progress_bar,
    @status_bar,
    @refresh_control,
    @webview,
    @camera_preview,
    @native_view,
    @tab_bar,
    @list,
    @checkbox,
    @radio,
    @chip,
    @snackbar,
    @fab,
    @icon_button,
    @segmented_button,
    @app_bar,
    @nav_bar,
    @nav_drawer,
    @nav_rail,
    @menu,
    @date_picker,
    @time_picker,
    @search_bar,
    @carousel,
  ]

  # ── Container entities (support children) ───────────────────────────────

  # -- Card ---------------------------------------------------------------

  defmodule Card do
    @moduledoc false
    defstruct variant: nil, elevation: nil, corner_radius: nil, padding: nil,
              background: nil, on_tap: nil, on_long_press: nil, fill_width: nil,
              accessibility_id: nil, children: [], __spark_metadata__: nil
  end

  @card %Spark.Dsl.Entity{
    name: :card,
    target: Card,
    describe: "Card container with elevation/shadow",
    examples: ["card variant: :elevated, elevation: 2.0, corner_radius: 12 do\n  text \"Card content\"\nend"],
    entities: [children: @leaf_entities],
    recursive_as: :children,
    schema: [
      variant: [type: {:one_of, [:filled, :outlined, :elevated]}, doc: "Card variant"],
      elevation: [type: :float, doc: "Shadow depth"],
      corner_radius: [type: :integer, doc: "Rounded corner radius"],
      padding: [type: :any, doc: "Padding (token or integer)"],
      background: [type: :any, doc: "Background color token"],
      on_tap: [type: :atom, doc: "Event handler for tap"],
      on_long_press: [type: :atom, doc: "Event handler for long press"],
      fill_width: [type: :boolean, doc: "Stretch to fill parent width"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- Badge --------------------------------------------------------------

  defmodule Badge do
    @moduledoc false
    defstruct count: nil, color: nil, text_color: nil, text_size: nil,
              position: nil, visible: nil, accessibility_id: nil,
              children: [], __spark_metadata__: nil
  end

  @badge %Spark.Dsl.Entity{
    name: :badge,
    target: Badge,
    describe: "Badge/notification dot container",
    examples: ["badge count: 5, color: :error do\n  icon \"notifications\"\nend"],
    entities: [children: @leaf_entities],
    recursive_as: :children,
    schema: [
      count: [type: :integer, doc: "Numeric badge value"],
      color: [type: :any, doc: "Badge background color"],
      text_color: [type: :any, doc: "Badge text color"],
      text_size: [type: :any, doc: "Badge text size"],
      position: [type: {:one_of, [:top_start, :top_end, :bottom_start, :bottom_end]}, doc: "Badge position"],
      visible: [type: :boolean, doc: "Whether the badge is shown"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- BottomSheet --------------------------------------------------------

  defmodule BottomSheet do
    @moduledoc false
    defstruct visible: nil, on_dismiss: nil, drag_indicator: nil, height: nil,
              corner_radius: nil, background: nil, accessibility_id: nil,
              children: [], __spark_metadata__: nil
  end

  @bottom_sheet %Spark.Dsl.Entity{
    name: :bottom_sheet,
    target: BottomSheet,
    describe: "Bottom sheet container",
    examples: ["bottom_sheet visible: true, on_dismiss: :dismissed, drag_indicator: true do\n  text \"Sheet content\"\nend"],
    entities: [children: @leaf_entities],
    recursive_as: :children,
    schema: [
      visible: [type: :boolean, doc: "Whether the sheet is shown"],
      on_dismiss: [type: :atom, doc: "Event handler when sheet is dismissed"],
      drag_indicator: [type: :boolean, doc: "Show drag handle at top"],
      height: [type: :integer, doc: "Sheet height in dp/pts"],
      corner_radius: [type: :integer, doc: "Rounded corners at the top"],
      background: [type: :any, doc: "Background color token"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- Tooltip -----------------------------------------------------------

  defmodule Tooltip do
    @moduledoc false
    defstruct text: nil, position: nil, visible: nil, delay: nil,
              accessibility_id: nil, children: [], __spark_metadata__: nil
  end

  @tooltip %Spark.Dsl.Entity{
    name: :tooltip,
    target: Tooltip,
    describe: "Tooltip container",
    examples: ["tooltip text: \"Helpful info\", position: :top do\n  icon \"help\"\nend"],
    entities: [children: @leaf_entities],
    recursive_as: :children,
    schema: [
      text: [type: :string, doc: "Tooltip text"],
      position: [type: {:one_of, [:top, :bottom, :left, :right]}, doc: "Tooltip position"],
      visible: [type: :boolean, doc: "Whether the tooltip is shown"],
      delay: [type: :integer, doc: "Show delay in ms"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- Column -------------------------------------------------------------

  defmodule Column do
    @moduledoc false
    defstruct padding: nil,
              padding_top: nil,
              padding_right: nil,
              padding_bottom: nil,
              padding_left: nil,
              gap: nil,
              background: nil,
              border_color: nil,
              border_width: nil,
              corner_radius: nil,
              fill_width: nil,
              width: nil,
              height: nil,
              alignment: nil,
              justify: nil,
              on_tap: nil,
              on_long_press: nil,
              on_double_tap: nil,
              on_swipe: nil,
              on_swipe_left: nil,
              on_swipe_right: nil,
              on_swipe_up: nil,
              on_swipe_down: nil,
              accessibility_id: nil,
              children: [],
              __spark_metadata__: nil
  end

  @column %Spark.Dsl.Entity{
    name: :column,
    target: Column,
    describe: "Vertical layout container (VStack)",
    examples: [
      "column padding: :space_md, gap: :space_sm do\n  text \"Title\"\n  text \"Subtitle\"\nend"
    ],
    entities: [children: @leaf_entities],
    recursive_as: :children,
    schema: [
      padding: [type: :any, doc: "Padding (token or integer)"],
      padding_top: [type: :any, doc: "Top padding"],
      padding_right: [type: :any, doc: "Right padding"],
      padding_bottom: [type: :any, doc: "Bottom padding"],
      padding_left: [type: :any, doc: "Left padding"],
      gap: [type: :any, doc: "Spacing between children (token or integer)"],
      background: [type: :any, doc: "Background color token"],
      border_color: [type: :any, doc: "Border color token"],
      border_width: [type: :integer, doc: "Border width"],
      corner_radius: [type: :integer, doc: "Rounded corner radius"],
      fill_width: [type: :boolean, doc: "Stretch to fill parent width"],
      width: [type: :integer, doc: "Width in dp/pts"],
      height: [type: :integer, doc: "Height in dp/pts"],
      on_tap: [type: :atom, doc: "Event handler for tap"],
      on_long_press: [type: :atom, doc: "Event handler for long press"],
      on_double_tap: [type: :atom, doc: "Event handler for double tap"],
      on_swipe: [type: :atom, doc: "Event handler for swipe"],
      on_swipe_left: [type: :atom, doc: "Event handler for swipe left"],
      on_swipe_right: [type: :atom, doc: "Event handler for swipe right"],
      on_swipe_up: [type: :atom, doc: "Event handler for swipe up"],
      on_swipe_down: [type: :atom, doc: "Event handler for swipe down"],
      accessibility_id: [type: :atom, doc: "Test identifier"],
      alignment: [type: {:one_of, [:start, :center, :end, :stretch]}, doc: "Horizontal alignment of children (:start, :center, :end, :stretch)"],
      justify: [type: {:one_of, [:start, :center, :end, :space_between]}, doc: "Vertical justification of children (:start, :center, :end, :space_between)"]
    ]
  }

  # -- Row ----------------------------------------------------------------

  defmodule Row do
    @moduledoc false
    defstruct padding: nil,
              padding_top: nil,
              padding_right: nil,
              padding_bottom: nil,
              padding_left: nil,
              gap: nil,
              background: nil,
              border_color: nil,
              border_width: nil,
              corner_radius: nil,
              fill_width: nil,
              width: nil,
              height: nil,
              alignment: nil,
              justify: nil,
              on_tap: nil,
              on_long_press: nil,
              on_double_tap: nil,
              on_swipe: nil,
              on_swipe_left: nil,
              on_swipe_right: nil,
              on_swipe_up: nil,
              on_swipe_down: nil,
              accessibility_id: nil,
              children: [],
              __spark_metadata__: nil
  end

  @row %Spark.Dsl.Entity{
    name: :row,
    target: Row,
    describe: "Horizontal layout container (HStack)",
    examples: [
      "row gap: :space_sm do\n  icon \"settings\"\n  text \"Settings\"\nend"
    ],
    entities: [children: @leaf_entities],
    recursive_as: :children,
    schema: [
      padding: [type: :any, doc: "Padding (token or integer)"],
      padding_top: [type: :any, doc: "Top padding"],
      padding_right: [type: :any, doc: "Right padding"],
      padding_bottom: [type: :any, doc: "Bottom padding"],
      padding_left: [type: :any, doc: "Left padding"],
      gap: [type: :any, doc: "Spacing between children"],
      background: [type: :any, doc: "Background color token"],
      border_color: [type: :any, doc: "Border color token"],
      border_width: [type: :integer, doc: "Border width"],
      corner_radius: [type: :integer, doc: "Rounded corner radius"],
      fill_width: [type: :boolean, doc: "Stretch to fill parent width"],
      width: [type: :integer, doc: "Width in dp/pts"],
      height: [type: :integer, doc: "Height in dp/pts"],
      on_tap: [type: :atom, doc: "Event handler for tap"],
      on_long_press: [type: :atom, doc: "Event handler for long press"],
      on_double_tap: [type: :atom, doc: "Event handler for double tap"],
      on_swipe: [type: :atom, doc: "Event handler for swipe"],
      on_swipe_left: [type: :atom, doc: "Event handler for swipe left"],
      on_swipe_right: [type: :atom, doc: "Event handler for swipe right"],
      on_swipe_up: [type: :atom, doc: "Event handler for swipe up"],
      on_swipe_down: [type: :atom, doc: "Event handler for swipe down"],
      accessibility_id: [type: :atom, doc: "Test identifier"],
      alignment: [type: {:one_of, [:start, :center, :end, :stretch]}, doc: "Vertical alignment of children (:start, :center, :end, :stretch)"],
      justify: [type: {:one_of, [:start, :center, :end, :space_between]}, doc: "Horizontal justification of children (:start, :center, :end, :space_between)"]
    ]
  }

  # -- Box (ZStack) -------------------------------------------------------

  defmodule Box do
    @moduledoc false
    defstruct padding: nil,
              padding_top: nil,
              padding_right: nil,
              padding_bottom: nil,
              padding_left: nil,
              gap: nil,
              background: nil,
              border_color: nil,
              border_width: nil,
              corner_radius: nil,
              fill_width: nil,
              width: nil,
              height: nil,
              on_tap: nil,
              on_long_press: nil,
              on_double_tap: nil,
              on_swipe: nil,
              on_swipe_left: nil,
              on_swipe_right: nil,
              on_swipe_up: nil,
              on_swipe_down: nil,
              accessibility_id: nil,
              children: [],
              __spark_metadata__: nil
  end

  @box %Spark.Dsl.Entity{
    name: :box,
    target: Box,
    describe: "Stacked container (ZStack) — children overlap",
    examples: [
      "box do\n  image \"bg.jpg\"\n  text \"Overlay\", text_color: :white\nend"
    ],
    entities: [children: @leaf_entities],
    recursive_as: :children,
    schema: [
      padding: [type: :any, doc: "Padding (token or integer)"],
      padding_top: [type: :any, doc: "Top padding"],
      padding_right: [type: :any, doc: "Right padding"],
      padding_bottom: [type: :any, doc: "Bottom padding"],
      padding_left: [type: :any, doc: "Left padding"],
      gap: [type: :any, doc: "Spacing between children"],
      background: [type: :any, doc: "Background color token"],
      border_color: [type: :any, doc: "Border color token"],
      border_width: [type: :integer, doc: "Border width"],
      corner_radius: [type: :integer, doc: "Rounded corner radius"],
      fill_width: [type: :boolean, doc: "Stretch to fill parent width"],
      width: [type: :integer, doc: "Width in dp/pts"],
      height: [type: :integer, doc: "Height in dp/pts"],
      on_tap: [type: :atom, doc: "Event handler for tap"],
      on_long_press: [type: :atom, doc: "Event handler for long press"],
      on_double_tap: [type: :atom, doc: "Event handler for double tap"],
      on_swipe: [type: :atom, doc: "Event handler for swipe"],
      on_swipe_left: [type: :atom, doc: "Event handler for swipe left"],
      on_swipe_right: [type: :atom, doc: "Event handler for swipe right"],
      on_swipe_up: [type: :atom, doc: "Event handler for swipe up"],
      on_swipe_down: [type: :atom, doc: "Event handler for swipe down"],
      accessibility_id: [type: :atom, doc: "Test identifier"]
    ]
  }

  # -- Scroll -------------------------------------------------------------

  defmodule Scroll do
    @moduledoc false
    defstruct horizontal: nil,
              show_indicator: nil,
              on_end_reached: nil,
              on_scroll: nil,
              padding: nil,
              background: nil,
              children: [],
              __spark_metadata__: nil
  end

  @scroll %Spark.Dsl.Entity{
    name: :scroll,
    target: Scroll,
    describe: "Scrollable container",
    examples: [
      "scroll padding: :space_md do\n  text \"Long content...\"\nend"
    ],
    entities: [children: @leaf_entities],
    recursive_as: :children,
    schema: [
      horizontal: [type: :boolean, doc: "Enable horizontal scrolling"],
      show_indicator: [type: :boolean, doc: "Show scroll indicator (default: true)"],
      on_end_reached: [type: :atom, doc: "Event handler when scroll reaches end"],
      on_scroll: [type: :atom, doc: "Event handler during scrolling"],
      padding: [type: :any, doc: "Padding"],
      background: [type: :any, doc: "Background color token"]
    ]
  }

  # -- Modal --------------------------------------------------------------

  defmodule Modal do
    @moduledoc false
    defstruct visible: nil,
              on_dismiss: nil,
              presentation_style: nil,
              children: [],
              __spark_metadata__: nil
  end

  @modal %Spark.Dsl.Entity{
    name: :modal,
    target: Modal,
    describe: "Modal overlay",
    examples: [
      "modal visible: true, on_dismiss: :dismissed do\n  text \"Modal content\"\nend"
    ],
    entities: [children: @leaf_entities],
    recursive_as: :children,
    schema: [
      visible: [type: :boolean, doc: "Show the modal"],
      on_dismiss: [type: :atom, doc: "Event handler when user dismisses"],
      presentation_style: [
        type: {:one_of, [:full_screen, :page_sheet]},
        doc: "Presentation style (default: :full_screen)"
      ]
    ]
  }

  # -- Pressable ----------------------------------------------------------

  defmodule Pressable do
    @moduledoc false
    defstruct on_press: nil,
              on_long_press: nil,
              children: [],
              __spark_metadata__: nil
  end

  @pressable %Spark.Dsl.Entity{
    name: :pressable,
    target: Pressable,
    describe: "Pressable wrapper",
    examples: [
      "pressable on_press: :card_tapped do\n  text \"Tap me\"\nend"
    ],
    entities: [children: @leaf_entities],
    recursive_as: :children,
    schema: [
      on_press: [type: :atom, doc: "Event handler for press"],
      on_long_press: [type: :atom, doc: "Event handler for long press"]
    ]
  }

  # -- SafeArea -----------------------------------------------------------

  defmodule SafeArea do
    @moduledoc false
    defstruct children: [], __spark_metadata__: nil
  end

  @safe_area %Spark.Dsl.Entity{
    name: :safe_area,
    target: SafeArea,
    describe: "Safe area container (avoids notches, status bar, etc.)",
    examples: [
      "safe_area do\n  text \"Safe content\"\nend"
    ],
    entities: [children: @leaf_entities],
    recursive_as: :children,
    schema: []
  }

  # ── Screen section ──────────────────────────────────────────────────────
  # The screen section holds all entities — both leaf and container.
  # Container entities use `recursive_as: :children` so they can nest
  # inside each other.

  @all_entities [
    @card,
    @badge,
    @bottom_sheet,
    @tooltip,
    @column,
    @row,
    @box,
    @scroll,
    @modal,
    @pressable,
    @safe_area
    | @leaf_entities
  ]

  @screen %Spark.Dsl.Section{
    name: :screen,
    describe: "Screen definition with UI components",
    schema: [
      name: [type: :atom, required: true, doc: "Screen identifier"]
    ],
    entities: @all_entities
  }

  # ── Extension registration ──────────────────────────────────────────────

  use Spark.Dsl.Extension,
    sections: [@attributes, @screen],
    transformers: [
      Dala.Spark.Transformers.GenerateMount,
      Dala.Spark.Transformers.Render,
      Dala.Spark.Transformers.Pubsub
    ],
    verifiers: [__MODULE__.Verifier]

  use Spark.Dsl, default_extensions: [extensions: __MODULE__]

  # Pubsub extension is automatically available via sections

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
      :on_tab_select
    ]

    @valid_attr_types [:integer, :string, :boolean, :float, :atom, :list, :map]

    @impl true
    def verify(dsl_state) do
      attr_errors = verify_attributes(dsl_state)
      entity_errors = verify_entities(dsl_state)

      case attr_errors ++ entity_errors do
        [] -> :ok
        msgs -> {:error, Enum.join(msgs, "; ")}
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

  # The dala/1 macro is a convenience wrapper that imports the section
  # builders. Spark auto-generates the __using__ macro via
  # `use Spark.Dsl, default_extensions: [extensions: __MODULE__]` above.
  defmacro dala(do: block) do
    quote do
      import Dala.Spark.Dsl, only: [attributes: 1, screen: 1]
      unquote(block)
    end
  end
end
