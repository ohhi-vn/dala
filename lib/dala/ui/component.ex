defmodule Dala.Ui.Component do
  @moduledoc """
  Central registry of all Dala UI components.

  This is the SINGLE SOURCE OF TRUTH for:
  - Component names and type atoms
  - Allowed props per component
  - Default props
  - Component category (`:leaf` vs `:container`)
  - Human-readable documentation

  All other modules (Widgets, DSL, Renderer, Diff, DevTools) derive their
  component knowledge from this module. To add a new component, define it
  here and all other modules pick it up automatically.
  """

  @type category :: :leaf | :container

  defstruct [
    :name,
    :type,
    :category,
    props: [],
    defaults: %{},
    doc: "",
    examples: [],
    # For containers: the atom key used for children in the DSL struct
    children_key: nil,
    # Optional transform function for special prop handling
    # Receives the props map and returns a transformed props map
    transform: nil
  ]

  @type t :: %__MODULE__{
          name: atom(),
          type: atom(),
          category: category(),
          props: [atom()],
          defaults: map(),
          doc: String.t(),
          examples: [String.t()],
          children_key: atom() | nil,
          transform: (map() -> map()) | nil
        }

  # ── Component Definitions ──────────────────────────────────────────────────

  @doc false
  def components do
    %{
      # ── Leaf Components ──────────────────────────────────────────────────

      text: %__MODULE__{
        name: :text,
        type: :text,
        category: :leaf,
        props: [
          :text,
          :text_color,
          :text_size,
          :font_weight,
          :font_family,
          :text_align,
          :italic,
          :line_height,
          :letter_spacing,
          :variant,
          :selectable,
          :padding,
          :padding_top,
          :padding_right,
          :padding_bottom,
          :padding_left,
          :background,
          :corner_radius,
          :fill_width,
          :on_tap,
          :on_long_press,
          :on_double_tap,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{text: ""},
        doc: "Display text",
        examples: [
          ~s(text "Hello, world!"),
          ~s(text "Count: @count", text_size: :xl, text_color: :on_surface)
        ]
      },
      button: %__MODULE__{
        name: :button,
        type: :button,
        category: :leaf,
        props: [
          :text,
          :title,
          :on_tap,
          :disabled,
          :text_color,
          :text_size,
          :font_weight,
          :background,
          :padding,
          :padding_top,
          :padding_right,
          :padding_bottom,
          :padding_left,
          :corner_radius,
          :fill_width,
          :accessibility_id,
          :variant,
          :icon,
          :elevation,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{text: ""},
        doc: "Tappable button",
        examples: [
          ~s(button "Press me", on_tap: :pressed),
          ~s(button "Submit", on_tap: :submit, background: :primary, text_color: :on_primary)
        ]
      },
      icon: %__MODULE__{
        name: :icon,
        type: :icon,
        category: :leaf,
        props: [
          :name,
          :text_size,
          :text_color,
          :padding,
          :background,
          :on_tap,
          :on_long_press,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{name: ""},
        doc: "Platform-native icon (SF Symbols on iOS, Material on Android)",
        examples: [
          ~s(icon "settings", text_size: 24, text_color: :on_surface),
          ~s(icon "chevron_right", on_tap: :navigate)
        ]
      },
      divider: %__MODULE__{
        name: :divider,
        type: :divider,
        category: :leaf,
        props: [
          :thickness,
          :color,
          :padding
        ],
        defaults: %{thickness: 1.0, color: :border},
        doc: "Horizontal or vertical divider line",
        examples: [
          ~s[divider()],
          ~s[divider thickness: 2, color: :primary]
        ]
      },
      empty_state: %__MODULE__{
        name: :empty_state,
        type: :empty_state,
        category: :leaf,
        props: [
          :icon,
          :title,
          :message,
          :action_label,
          :on_action,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{},
        doc: "Empty state placeholder with icon, message, and optional action",
        examples: [
          ~s[empty_state(icon: "inbox", title: "Nothing here", message: "Items appear here", action_label: "Get started", on_action: :start)]
        ]
      },
      spacer: %__MODULE__{
        name: :spacer,
        type: :spacer,
        category: :leaf,
        props: [
          :size,
          :fixed_size
        ],
        defaults: %{},
        doc: "Flexible or fixed space",
        examples: [
          ~s[spacer()],
          ~s(spacer size: 20)
        ]
      },
      text_field: %__MODULE__{
        name: :text_field,
        type: :text_field,
        category: :leaf,
        props: [
          :text,
          :placeholder,
          :on_change,
          :on_focus,
          :on_blur,
          :on_submit,
          :on_compose,
          :secure,
          :keyboard_type,
          :return_key,
          :max_length,
          :auto_capitalize,
          :auto_correct,
          :min_lines,
          :max_lines,
          :disabled,
          :text_color,
          :text_size,
          :background,
          :padding,
          :corner_radius,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{text: ""},
        doc: "Text input field",
        examples: [
          ~s(text_field placeholder: "Enter name", on_change: :name_changed),
          ~s(text_field keyboard_type: :email, return_key: :next, on_submit: :next_field)
        ]
      },
      toggle: %__MODULE__{
        name: :toggle,
        type: :toggle,
        category: :leaf,
        props: [
          :value,
          :on_change,
          :text,
          :disabled,
          :text_color,
          :text_size,
          :track_color,
          :thumb_color,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{value: false},
        doc: "On/off toggle switch",
        examples: [
          ~s(toggle value: true, on_change: :notifications_toggled, text: "Notifications")
        ]
      },
      slider: %__MODULE__{
        name: :slider,
        type: :slider,
        category: :leaf,
        props: [
          :value,
          :min_value,
          :max_value,
          :step,
          :on_change,
          :disabled,
          :text_color,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{value: 0.5, min_value: 0, max_value: 1.0, step: 0.01},
        doc: "Slider for numeric input",
        examples: [
          ~s(slider value: 0.5, min_value: 0, max_value: 100, on_change: :volume_changed)
        ]
      },
      switch: %__MODULE__{
        name: :switch,
        type: :switch,
        category: :leaf,
        props: [
          :value,
          :on_toggle,
          :disabled,
          :text,
          :text_color,
          :track_color,
          :thumb_color,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{value: false},
        doc: "On/off switch",
        examples: [
          ~s(switch value: true, on_toggle: :toggled)
        ]
      },
      stepper: %__MODULE__{
        name: :stepper,
        type: :stepper,
        category: :leaf,
        props: [
          :steps,
          :current,
          :color,
          :connector_color,
          :completed_icon,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{steps: [], current: 0, completed_icon: "check"},
        doc: "Multi-step indicator for forms and onboarding",
        examples: [
          ~s(stepper steps: ["Account", "Profile", "Done"], current: @step)
        ]
      },
      image: %__MODULE__{
        name: :image,
        type: :image,
        category: :leaf,
        props: [
          :source,
          :src,
          :width,
          :height,
          :resize_mode,
          :corner_radius,
          :background,
          :placeholder_color,
          :on_error,
          :on_load,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{source: ""},
        doc: "Image display",
        examples: [
          ~s(image "https://example.com/photo.jpg"),
          ~s(image "logo.png", width: 100, height: 100, resize_mode: :contain)
        ]
      },
      avatar: %__MODULE__{
        name: :avatar,
        type: :avatar,
        category: :leaf,
        props: [
          :src,
          :fallback,
          :size,
          :shape,
          :background,
          :text_color,
          :on_tap,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{size: 40, shape: :circle},
        doc: "Profile image with fallback initials",
        examples: [
          ~s(avatar src: @user.photo_url, fallback: "JS", size: 48, shape: :circle),
          ~s(avatar fallback: "AB", background: :primary, text_color: :on_primary, size: 40)
        ]
      },
      video: %__MODULE__{
        name: :video,
        type: :video,
        category: :leaf,
        props: [
          :source,
          :src,
          :autoplay,
          :loop,
          :muted,
          :controls,
          :width,
          :height,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{source: ""},
        doc: "Video player",
        examples: [
          ~s(video "https://example.com/clip.mp4", autoplay: true, loop: true)
        ]
      },
      activity_indicator: %__MODULE__{
        name: :activity_indicator,
        type: :activity_indicator,
        category: :leaf,
        props: [
          :size,
          :color,
          :animating,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{},
        doc: "Loading spinner",
        examples: [
          ~s(activity_indicator size: :large, color: :primary)
        ]
      },
      skeleton: %__MODULE__{
        name: :skeleton,
        type: :skeleton,
        category: :leaf,
        props: [
          :width,
          :height,
          :corner_radius,
          :color,
          :animate,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{animate: true},
        doc: "Animated shimmer placeholder for loading content",
        examples: [
          ~s(skeleton width: 200, height: 16, corner_radius: :radius_sm),
          ~s(skeleton width: :fill, height: 120, corner_radius: :radius_md)
        ]
      },
      progress_bar: %__MODULE__{
        name: :progress_bar,
        type: :progress_bar,
        category: :leaf,
        props: [
          :progress,
          :indeterminate,
          :color,
          :background,
          :height,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{progress: 0.0},
        doc: "Progress bar",
        examples: [
          ~s(progress_bar progress: 0.7, color: :primary)
        ]
      },
      status_bar: %__MODULE__{
        name: :status_bar,
        type: :status_bar,
        category: :leaf,
        props: [
          :bar_style,
          :hidden,
          :background,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{},
        doc: "Status bar configuration",
        examples: [
          ~s(status_bar bar_style: :light_content, hidden: false)
        ]
      },
      refresh_control: %__MODULE__{
        name: :refresh_control,
        type: :refresh_control,
        category: :leaf,
        props: [
          :on_refresh,
          :refreshing,
          :tint_color,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{refreshing: false},
        doc: "Pull-to-refresh control",
        examples: [
          ~s(refresh_control on_refresh: :reload, refreshing: false)
        ]
      },
      webview: %__MODULE__{
        name: :webview,
        type: :webview,
        category: :leaf,
        props: [
          :url,
          :source,
          :show_url,
          :title,
          :width,
          :height,
          :allow,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{source: ""},
        doc: "Inline web view",
        examples: [
          ~s(webview "https://elixir-lang.org"),
          ~s(webview "https://example.com", show_url: true, width: 400, height: 600)
        ]
      },
      camera_preview: %__MODULE__{
        name: :camera_preview,
        type: :camera_preview,
        category: :leaf,
        props: [
          :facing,
          :width,
          :height,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{facing: :back},
        doc: "Camera preview",
        examples: [
          ~s(camera_preview facing: :front, width: 300, height: 400)
        ]
      },
      native_view: %__MODULE__{
        name: :native_view,
        type: :native_view,
        category: :leaf,
        props: [
          :module,
          :id,
          :props
        ],
        defaults: %{},
        doc: "Embed a native view component",
        examples: [
          ~s(native_view MyApp.ChartComponent, id: :revenue_chart)
        ]
      },
      tab_bar: %__MODULE__{
        name: :tab_bar,
        type: :tab_bar,
        category: :leaf,
        props: [
          :tabs,
          :active_tab,
          :on_tab_select,
          :text_color,
          :background,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{tabs: []},
        doc: "Tab bar for switching between screens",
        examples: [
          ~s(tab_bar tabs: [%{id: "home", label: "Home", icon: "home"}], active_tab: "home", on_tab_select: :tab_changed)
        ]
      },
      list: %__MODULE__{
        name: :list,
        type: :list,
        category: :leaf,
        props: [
          :id,
          :data,
          :items,
          :on_end_reached,
          :on_refresh,
          :refreshing,
          :empty_text,
          :separator,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{items: []},
        doc: "Data-driven list (FlatList equivalent)",
        examples: [
          ~s(list :my_list, data: @items, on_end_reached: :load_more)
        ],
        transform: fn props ->
          Map.put_new(props, :items, props[:data] || [])
          |> Map.drop([:data])
        end
      },
      list_item: %__MODULE__{
        name: :list_item,
        type: :list_item,
        category: :leaf,
        props: [
          :on_tap,
          :on_long_press,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{},
        doc: "List item container",
        examples: [
          ~s(list_item on_tap: :item_selected)
        ]
      },
      checkbox: %__MODULE__{
        name: :checkbox,
        type: :checkbox,
        category: :leaf,
        props: [
          :value,
          :on_change,
          :label,
          :disabled,
          :text_color,
          :text_size,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{value: false},
        doc: "Checkbox input",
        examples: [
          ~s(checkbox value: true, on_change: :agree_toggled, label: "I agree")
        ]
      },
      radio: %__MODULE__{
        name: :radio,
        type: :radio,
        category: :leaf,
        props: [
          :selected,
          :on_select,
          :label,
          :group,
          :disabled,
          :text_color,
          :text_size,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{selected: false},
        doc: "Radio button",
        examples: [
          ~s(radio selected: true, on_select: :option_a, label: "Option A", group: "choices")
        ]
      },
      chip: %__MODULE__{
        name: :chip,
        type: :chip,
        category: :leaf,
        props: [
          :label,
          :variant,
          :selected,
          :on_tap,
          :icon,
          :on_remove,
          :disabled,
          :enabled,
          :text_color,
          :text_size,
          :background,
          :corner_radius,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{},
        doc: "Chip/tag component",
        examples: [
          ~s(chip label: "Filter", variant: :filter, selected: true, on_tap: :chip_tapped)
        ]
      },
      snackbar: %__MODULE__{
        name: :snackbar,
        type: :snackbar,
        category: :leaf,
        props: [
          :message,
          :action_label,
          :on_action,
          :duration,
          :visible,
          :text_color,
          :background,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{visible: false},
        doc: "Snackbar/toast notification",
        examples: [
          ~s(snackbar message: "Item deleted", action_label: "Undo", on_action: :undo)
        ]
      },
      fab: %__MODULE__{
        name: :fab,
        type: :fab,
        category: :leaf,
        props: [
          :icon,
          :text,
          :on_tap,
          :background,
          :color,
          :text_color,
          :elevation,
          :corner_radius,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{},
        doc: "Floating action button",
        examples: [
          ~s(fab icon: "edit", text: "Compose", on_tap: :compose)
        ]
      },
      icon_button: %__MODULE__{
        name: :icon_button,
        type: :icon_button,
        category: :leaf,
        props: [
          :icon,
          :on_tap,
          :selected,
          :enabled,
          :color,
          :text_color,
          :background,
          :size,
          :disabled,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{},
        doc: "Icon-only button",
        examples: [
          ~s(icon_button icon: "favorite", on_tap: :favorite_tapped)
        ]
      },
      segmented_button: %__MODULE__{
        name: :segmented_button,
        type: :segmented_button,
        category: :leaf,
        props: [
          :segments,
          :selected,
          :on_select,
          :text_color,
          :background,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{segments: []},
        doc: "Segmented button control",
        examples: [
          ~s(segmented_button segments: [%{id: "day", label: "Day"}, %{id: "week", label: "Week"}], selected: "week", on_select: :range_changed)
        ]
      },
      app_bar: %__MODULE__{
        name: :app_bar,
        type: :app_bar,
        category: :leaf,
        props: [
          :title,
          :leading_icon,
          :on_leading,
          :trailing_actions,
          :text_color,
          :background,
          :elevation,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{title: ""},
        doc: "Top app bar",
        examples: [
          ~s(app_bar title: "My App", leading_icon: "back", on_leading: :back_pressed, trailing_actions: [%{icon: "search", on_tap: :search}])
        ]
      },
      nav_bar: %__MODULE__{
        name: :nav_bar,
        type: :nav_bar,
        category: :leaf,
        props: [
          :items,
          :active,
          :on_select,
          :text_color,
          :background,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{items: []},
        doc: "Bottom navigation bar",
        examples: [
          ~s(nav_bar items: [%{id: "home", label: "Home", icon: "home"}], active: "home", on_select: :tab_changed)
        ]
      },
      nav_drawer: %__MODULE__{
        name: :nav_drawer,
        type: :nav_drawer,
        category: :leaf,
        props: [
          :visible,
          :on_dismiss,
          :items,
          :active,
          :on_select,
          :header,
          :background,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{visible: false, items: []},
        doc: "Navigation drawer",
        examples: [
          ~s(nav_drawer visible: true, on_dismiss: :drawer_dismissed, items: [%{id: "home", label: "Home", icon: "home"}], active: "home", on_select: :nav_changed)
        ]
      },
      nav_rail: %__MODULE__{
        name: :nav_rail,
        type: :nav_rail,
        category: :leaf,
        props: [
          :items,
          :active,
          :on_select,
          :text_color,
          :background,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{items: []},
        doc: "Navigation rail (side navigation)",
        examples: [
          ~s(nav_rail items: [%{id: "home", label: "Home", icon: "home"}], active: "home", on_select: :rail_changed)
        ]
      },
      menu: %__MODULE__{
        name: :menu,
        type: :menu,
        category: :leaf,
        props: [
          :items,
          :visible,
          :on_select,
          :text_color,
          :background,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{visible: false, items: []},
        doc: "Dropdown menu",
        examples: [
          ~s(menu items: [%{label: "Edit", action: :edit}, %{label: "Delete", action: :delete}], visible: true, on_select: :menu_selected)
        ]
      },
      date_picker: %__MODULE__{
        name: :date_picker,
        type: :date_picker,
        category: :leaf,
        props: [
          :visible,
          :on_select,
          :on_dismiss,
          :selected_date,
          :min_date,
          :max_date,
          :title,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{visible: false},
        doc: "Date picker",
        examples: [
          ~s(date_picker visible: true, on_select: :date_picked, selected_date: "2025-01-15")
        ]
      },
      time_picker: %__MODULE__{
        name: :time_picker,
        type: :time_picker,
        category: :leaf,
        props: [
          :visible,
          :on_select,
          :on_dismiss,
          :selected_time,
          :title,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{visible: false},
        doc: "Time picker",
        examples: [
          ~s(time_picker visible: true, on_select: :time_picked, selected_time: "09:30")
        ]
      },
      search_bar: %__MODULE__{
        name: :search_bar,
        type: :search_bar,
        category: :leaf,
        props: [
          :placeholder,
          :text,
          :on_change,
          :on_submit,
          :on_focus,
          :active,
          :on_tap,
          :value,
          :text_color,
          :background,
          :corner_radius,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{value: ""},
        doc: "Search bar",
        examples: [
          ~s(search_bar placeholder: "Search...", on_change: :search_changed, on_submit: :search_submitted)
        ]
      },
      carousel: %__MODULE__{
        name: :carousel,
        type: :carousel,
        category: :leaf,
        props: [
          :id,
          :items,
          :data,
          :on_page_change,
          :loop,
          :autoplay,
          :autoplay_interval,
          :peek,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{items: []},
        doc: "Carousel/slideshow component",
        examples: [
          ~s(carousel :my_carousel, items: @slides, on_page_change: :page_changed)
        ]
      },

      # ── Container Components ──────────────────────────────────────────────

      column: %__MODULE__{
        name: :column,
        type: :column,
        category: :container,
        props: [
          :padding,
          :padding_top,
          :padding_right,
          :padding_bottom,
          :padding_left,
          :gap,
          :spacing,
          :background,
          :corner_radius,
          :fill_width,
          :fill_height,
          :alignment,
          :cross_alignment,
          :scrollable,
          :on_tap,
          :on_long_press,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{},
        doc: "Vertical layout container",
        children_key: :children,
        examples: [
          ~s(column padding: :space_md, gap: :space_sm do\n  text "Title"\n  text "Subtitle"\nend)
        ]
      },
      row: %__MODULE__{
        name: :row,
        type: :row,
        category: :container,
        props: [
          :padding,
          :padding_top,
          :padding_right,
          :padding_bottom,
          :padding_left,
          :gap,
          :spacing,
          :background,
          :corner_radius,
          :fill_width,
          :fill_height,
          :alignment,
          :cross_alignment,
          :scrollable,
          :on_tap,
          :on_long_press,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{},
        doc: "Horizontal layout container",
        children_key: :children,
        examples: [
          ~s(row gap: :space_sm do\n  icon "settings"\n  text "Settings"\nend)
        ]
      },
      box: %__MODULE__{
        name: :box,
        type: :box,
        category: :container,
        props: [
          :padding,
          :padding_top,
          :padding_right,
          :padding_bottom,
          :padding_left,
          :background,
          :corner_radius,
          :fill_width,
          :fill_height,
          :alignment,
          :cross_alignment,
          :width,
          :height,
          :min_width,
          :min_height,
          :max_width,
          :max_height,
          :on_tap,
          :on_long_press,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{},
        doc: "Box with absolute positioning for overlapping children",
        children_key: :children,
        examples: [
          ~s(box do\n  image "bg.jpg"\n  text "Overlay", text_color: :white\nend)
        ]
      },
      scroll: %__MODULE__{
        name: :scroll,
        type: :scroll,
        category: :container,
        props: [
          :padding,
          :padding_top,
          :padding_right,
          :padding_bottom,
          :padding_left,
          :background,
          :fill_width,
          :fill_height,
          :direction,
          :shows_indicator,
          :on_scroll,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{direction: :vertical},
        doc: "Scrollable container",
        children_key: :children,
        examples: [
          ~s(scroll padding: :space_md do
  text "Long content..."
end)
        ]
      },
      grid: %__MODULE__{
        name: :grid,
        type: :grid,
        category: :container,
        props: [
          :columns,
          :gap,
          :row_gap,
          :padding,
          :padding_top,
          :padding_right,
          :padding_bottom,
          :padding_left,
          :background,
          :corner_radius,
          :fill_width,
          :on_tap,
          :on_long_press,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{columns: 2},
        doc: "Grid layout container (LazyVerticalGrid / LazyVGrid equivalent)",
        children_key: :children,
        examples: [
          ~s(grid columns: 2, gap: :space_sm do
  for item <- @items do
    card do
      text item.title
    end
  end
end)
        ]
      },
      modal: %__MODULE__{
        name: :modal,
        type: :modal,
        category: :container,
        props: [
          :visible,
          :on_dismiss,
          :background,
          :corner_radius,
          :presentation_style,
          :animation,
          :drag_indicator,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{visible: false},
        doc: "Modal overlay container",
        children_key: :children,
        examples: [
          ~s(modal visible: true, on_dismiss: :dismissed do\n  text "Modal content"\nend)
        ]
      },
      pressable: %__MODULE__{
        name: :pressable,
        type: :pressable,
        category: :container,
        props: [
          :on_press,
          :on_long_press,
          :on_double_tap,
          :disabled,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{},
        doc: "Pressable wrapper container",
        children_key: :children,
        examples: [
          ~s(pressable on_press: :card_tapped do\n  text "Tap me"\nend)
        ]
      },
      safe_area: %__MODULE__{
        name: :safe_area,
        type: :safe_area,
        category: :container,
        props: [
          :edges,
          :background,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{edges: [:top, :bottom]},
        doc: "Safe area inset container",
        children_key: :children,
        examples: [
          ~s(safe_area do\n  text "Safe content"\nend)
        ]
      },
      card: %__MODULE__{
        name: :card,
        type: :card,
        category: :container,
        props: [
          :variant,
          :elevation,
          :corner_radius,
          :padding,
          :background,
          :on_tap,
          :on_long_press,
          :fill_width,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{variant: :elevated, elevation: 1.0},
        doc: "Card container with elevation/shadow",
        children_key: :children,
        examples: [
          ~s(card variant: :elevated, elevation: 2.0, corner_radius: 12 do\n  text "Card content"\nend)
        ]
      },
      badge: %__MODULE__{
        name: :badge,
        type: :badge,
        category: :container,
        props: [
          :count,
          :color,
          :text_color,
          :text_size,
          :position,
          :visible,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{count: 0, position: :top_end},
        doc: "Badge/notification dot container",
        children_key: :children,
        examples: [
          ~s(badge count: 5, color: :error do\n  icon "notifications"\nend)
        ]
      },
      bottom_sheet: %__MODULE__{
        name: :bottom_sheet,
        type: :bottom_sheet,
        category: :container,
        props: [
          :visible,
          :on_dismiss,
          :drag_indicator,
          :height,
          :corner_radius,
          :background,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{visible: false, drag_indicator: true},
        doc: "Bottom sheet container",
        children_key: :children,
        examples: [
          ~s(bottom_sheet visible: true, on_dismiss: :dismissed, drag_indicator: true do\n  text "Sheet content"\nend)
        ]
      },
      tooltip: %__MODULE__{
        name: :tooltip,
        type: :tooltip,
        category: :container,
        props: [
          :text,
          :position,
          :visible,
          :delay,
          :accessibility_id,
          :accessibility_label,
          :accessibility_hint,
          :accessibility_role,
          :accessibility_value,
          :accessibility_hidden
        ],
        defaults: %{visible: false, position: :bottom, delay: 500},
        doc: "Tooltip container",
        children_key: :children,
        examples: [
          ~s(tooltip text: "Helpful info", position: :top do\n  icon "help"\nend)
        ]
      }
    }
  end

  # ── Public API ─────────────────────────────────────────────────────────────

  @doc "Get all components as a keyword list"
  @spec all() :: [{atom(), t()}]
  def all, do: components() |> Map.to_list()

  @doc "Get leaf components as a keyword list"
  @spec leaf_components() :: [{atom(), t()}]
  def leaf_components do
    components()
    |> Enum.filter(fn {_name, comp} -> comp.category == :leaf end)
    |> Enum.sort_by(fn {name, _} -> name end)
  end

  @doc "Get container components as a keyword list"
  @spec container_components() :: [{atom(), t()}]
  def container_components do
    components()
    |> Enum.filter(fn {_name, comp} -> comp.category == :container end)
    |> Enum.sort_by(fn {name, _} -> name end)
  end

  @doc "Get a single component by name"
  @spec get(atom()) :: t() | nil
  def get(name) when is_atom(name) do
    Map.get(components(), name)
  end

  @doc "Get the props list for a component by name"
  @spec props(atom()) :: [atom()]
  def props(name) when is_atom(name) do
    case Map.get(components(), name) do
      nil -> []
      comp -> comp.props
    end
  end

  @doc "Get the prop schema for a component by name"
  @spec prop_schema(atom()) :: [{atom(), keyword()}]
  def prop_schema(name) when is_atom(name) do
    case Map.get(components(), name) do
      nil ->
        []

      comp ->
        comp.props
        |> Enum.map(fn prop ->
          {prop, [type: :any, doc: "The `#{prop}` prop for `#{name}`"]}
        end)
    end
  end

  @doc "Apply a component's transform function to props"
  @spec transform_props(atom(), map()) :: map()
  def transform_props(name, props) when is_atom(name) and is_map(props) do
    case Map.get(components(), name) do
      nil -> props
      %{transform: nil} -> props
      %{transform: transform} -> transform.(props)
    end
  end
end
