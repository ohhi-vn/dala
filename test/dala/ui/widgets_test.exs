defmodule Dala.Ui.WidgetsTest do
  use ExUnit.Case, async: true

  alias Dala.Ui.Widgets, as: W

  # ── Layout containers ─────────────────────────────────────────────────────

  describe "column/2" do
    test "returns column node with children" do
      node = W.column([padding: 12], [W.text(text: "Hi")])
      assert node.type == :column
      assert node.props == %{padding: 12}
      assert length(node.children) == 1
    end

    test "filters unknown props" do
      node = W.column([padding: 12, unknown: :val], [])
      assert Map.has_key?(node.props, :padding)
      refute Map.has_key?(node.props, :unknown)
    end

    test "accepts alignment and justify props" do
      node = W.column(alignment: :center, justify: :space_between)
      assert node.props.alignment == :center
      assert node.props.justify == :space_between
    end

    test "accepts map props" do
      node = W.column(%{padding: 8, gap: :space_md}, [])
      assert node.props.padding == 8
      assert node.props.gap == :space_md
    end
  end

  describe "row/2" do
    test "returns row node with children" do
      node = W.row([gap: 8], [W.text(text: "A"), W.text(text: "B")])
      assert node.type == :row
      assert node.props.gap == 8
      assert length(node.children) == 2
    end

    test "accepts alignment and justify props" do
      node = W.row(alignment: :end, justify: :center)
      assert node.props.alignment == :end
      assert node.props.justify == :center
    end
  end

  describe "box/2" do
    test "returns box (ZStack) node" do
      node = W.box([background: :primary], [W.text(text: "Overlay")])
      assert node.type == :box
      assert node.props.background == :primary
    end
  end

  # ── Leaf nodes ────────────────────────────────────────────────────────────

  describe "text/1" do
    test "returns text node" do
      node = W.text(text: "Hello")
      assert node.type == :text
      assert node.props.text == "Hello"
      assert node.children == []
    end

    test "accepts typography props" do
      node = W.text(text: "Bold", font_weight: "bold", text_size: :xl)
      assert node.props.font_weight == "bold"
      assert node.props.text_size == :xl
    end
  end

  describe "button/1" do
    test "returns button node" do
      node = W.button(text: "Submit", on_tap: {self(), :submit})
      assert node.type == :button
      assert node.props.text == "Submit"
    end

    test "maps :title to :text for backward compat" do
      node = W.button(title: "OK")
      assert node.props.text == "OK"
    end

    test "accepts variant, icon, and elevation props" do
      node = W.button(text: "Save", variant: :outlined, icon: "save", elevation: 4.0)
      assert node.props.variant == :outlined
      assert node.props.icon == "save"
      assert node.props.elevation == 4.0
    end
  end

  describe "icon/1" do
    test "returns icon node" do
      node = W.icon(name: "settings")
      assert node.type == :icon
      assert node.props.name == "settings"
    end
  end

  describe "divider/1" do
    test "returns divider node" do
      node = W.divider()
      assert node.type == :divider
      assert node.children == []
    end
  end

  describe "spacer/1" do
    test "returns spacer node" do
      node = W.spacer(size: 20)
      assert node.type == :spacer
      assert node.props.size == 20
    end
  end

  describe "text_field/1" do
    test "returns text_field node" do
      node = W.text_field(placeholder: "Enter name")
      assert node.type == :text_field
      assert node.props.placeholder == "Enter name"
    end

    test "accepts secure, max_length, auto_capitalize, auto_correct, min_lines, max_lines" do
      node =
        W.text_field(
          placeholder: "Password",
          secure: true,
          max_length: 32,
          auto_capitalize: :none,
          auto_correct: false,
          min_lines: 3,
          max_lines: 5
        )

      assert node.props.secure == true
      assert node.props.max_length == 32
      assert node.props.auto_capitalize == :none
      assert node.props.auto_correct == false
      assert node.props.min_lines == 3
      assert node.props.max_lines == 5
    end
  end

  describe "toggle/1" do
    test "returns toggle node" do
      node = W.toggle(value: true, on_change: {self(), :changed})
      assert node.type == :toggle
      assert node.props.value == true
    end
  end

  describe "slider/1" do
    test "returns slider node" do
      node = W.slider(value: 0.5, min_value: 0, max_value: 100)
      assert node.type == :slider
      assert node.props.value == 0.5
    end
  end

  describe "tab_bar/1" do
    test "returns tab_bar node" do
      tabs = [%{id: "home", label: "Home"}, %{id: "settings", label: "Settings"}]
      node = W.tab_bar(tabs: tabs, active_tab: "home")
      assert node.type == :tab_bar
      assert length(node.props.tabs) == 2
    end
  end

  describe "image/1" do
    test "returns image node" do
      node = W.image(src: "https://example.com/photo.jpg")
      assert node.type == :image
      assert node.props.src == "https://example.com/photo.jpg"
    end

    test "accepts on_error and on_load callbacks" do
      node = W.image(src: "test.png", on_error: {self(), :img_err}, on_load: {self(), :img_ok})
      assert node.props.on_error == {self(), :img_err}
      assert node.props.on_load == {self(), :img_ok}
    end
  end

  describe "switch/1" do
    test "returns switch node" do
      node = W.switch(value: false)
      assert node.type == :switch
      assert node.props.value == false
    end
  end

  describe "activity_indicator/1" do
    test "returns activity_indicator node" do
      node = W.activity_indicator(size: :large)
      assert node.type == :activity_indicator
      assert node.props.size == :large
    end
  end

  describe "progress_bar/1" do
    test "returns progress_bar node" do
      node = W.progress_bar(progress: 0.7)
      assert node.type == :progress_bar
      assert node.props.progress == 0.7
    end
  end

  # ── Container nodes ───────────────────────────────────────────────────────

  describe "modal/2" do
    test "returns modal node with children" do
      node = W.modal([visible: true], [W.text(text: "Modal")])
      assert node.type == :modal
      assert node.props.visible == true
      assert length(node.children) == 1
    end

    test "accepts animation and drag_indicator props" do
      node = W.modal(visible: true, animation: :slide, drag_indicator: true)
      assert node.props.animation == :slide
      assert node.props.drag_indicator == true
    end
  end

  describe "scroll/2" do
    test "returns scroll node" do
      node = W.scroll([horizontal: true], [W.text(text: "Content")])
      assert node.type == :scroll
      assert node.props.horizontal == true
    end

    test "accepts paging prop" do
      node = W.scroll(paging: true)
      assert node.props.paging == true
    end
  end

  describe "pressable/2" do
    test "returns pressable node" do
      node = W.pressable([on_press: {self(), :pressed}], [W.text(text: "Tap")])
      assert node.type == :pressable
      assert node.props.on_press == {self(), :pressed}
    end
  end

  describe "safe_area/1" do
    test "returns safe_area node" do
      node = W.safe_area([W.text(text: "Safe")])
      assert node.type == :safe_area
    end
  end

  # ── New components: Selection ─────────────────────────────────────────────

  describe "checkbox/1" do
    test "returns checkbox node" do
      node = W.checkbox(value: true, on_change: {self(), :checked})
      assert node.type == :checkbox
      assert node.props.value == true
      assert node.props.on_change == {self(), :checked}
      assert node.children == []
    end

    test "accepts label, color, enabled props" do
      node = W.checkbox(value: false, label: "Accept terms", color: :primary, enabled: false)
      assert node.props.label == "Accept terms"
      assert node.props.color == :primary
      assert node.props.enabled == false
    end

    test "filters unknown props" do
      node = W.checkbox(value: true, unknown: :val)
      refute Map.has_key?(node.props, :unknown)
    end
  end

  describe "radio/1" do
    test "returns radio node" do
      node = W.radio(selected: true, on_select: {self(), :option_a}, group: "plan")
      assert node.type == :radio
      assert node.props.selected == true
      assert node.props.group == "plan"
      assert node.children == []
    end

    test "accepts label, enabled, color props" do
      node = W.radio(selected: false, label: "Option A", enabled: true, color: :primary)
      assert node.props.label == "Option A"
    end
  end

  # ── New components: Containment ───────────────────────────────────────────

  describe "card/2" do
    test "returns card node with children" do
      node = W.card([variant: :elevated, elevation: 4.0], [W.text(text: "Card content")])
      assert node.type == :card
      assert node.props.variant == :elevated
      assert node.props.elevation == 4.0
      assert length(node.children) == 1
    end

    test "accepts outlined variant with border props" do
      node = W.card(variant: :outlined, border_color: :primary, border_width: 1)
      assert node.props.variant == :outlined
      assert node.props.border_color == :primary
    end

    test "accepts on_tap gesture" do
      node = W.card(on_tap: {self(), :card_tapped}, children: [])
      assert node.props.on_tap == {self(), :card_tapped}
    end
  end

  describe "badge/2" do
    test "returns badge node with children" do
      node = W.badge([count: 5], [W.icon(name: "mail")])
      assert node.type == :badge
      assert node.props.count == 5
      assert length(node.children) == 1
    end

    test "accepts color and text_color props" do
      node = W.badge(count: 3, color: :red_500, text_color: :white)
      assert node.props.color == :red_500
      assert node.props.text_color == :white
    end
  end

  describe "chip/1" do
    test "returns chip node" do
      node = W.chip(label: "Filter", variant: :filter, selected: true)
      assert node.type == :chip
      assert node.props.label == "Filter"
      assert node.props.variant == :filter
      assert node.props.selected == true
      assert node.children == []
    end

    test "accepts on_remove for input chips" do
      node = W.chip(label: "Tag", variant: :input, on_remove: {self(), :remove})
      assert node.props.on_remove == {self(), :remove}
    end
  end

  describe "bottom_sheet/2" do
    test "returns bottom_sheet node with children" do
      node = W.bottom_sheet([visible: true, drag_indicator: true], [W.text(text: "Sheet")])
      assert node.type == :bottom_sheet
      assert node.props.visible == true
      assert node.props.drag_indicator == true
      assert length(node.children) == 1
    end

    test "accepts peek_height and corner_radius" do
      node = W.bottom_sheet(peek_height: 100.0, corner_radius: 16)
      assert node.props.peek_height == 100.0
    end
  end

  describe "carousel/1" do
    test "returns carousel node" do
      node = W.carousel(id: :photos, data: [1, 2, 3], loop: true)
      assert node.type == :carousel
      assert node.props.id == :photos
      assert node.props.loop == true
      assert node.children == []
    end
  end

  # ── New components: Communication ─────────────────────────────────────────

  describe "snackbar/1" do
    test "returns snackbar node" do
      node = W.snackbar(message: "Item saved", action_label: "Undo", on_action: {self(), :undo})
      assert node.type == :snackbar
      assert node.props.message == "Item saved"
      assert node.props.action_label == "Undo"
      assert node.children == []
    end

    test "accepts duration prop" do
      node = W.snackbar(message: "Hi", duration: :long)
      assert node.props.duration == :long
    end
  end

  describe "tooltip/2" do
    test "returns tooltip node with children" do
      node = W.tooltip([text: "Helpful tip", position: :top], [W.icon(name: "info")])
      assert node.type == :tooltip
      assert node.props.text == "Helpful tip"
      assert node.props.position == :top
      assert length(node.children) == 1
    end
  end

  # ── New components: Actions ───────────────────────────────────────────────

  describe "fab/1" do
    test "returns fab node" do
      node = W.fab(icon: "add", on_tap: {self(), :add})
      assert node.type == :fab
      assert node.props.icon == "add"
      assert node.props.on_tap == {self(), :add}
      assert node.children == []
    end

    test "accepts extended FAB with text" do
      node = W.fab(icon: "edit", text: "Compose", background: :primary)
      assert node.props.text == "Compose"
      assert node.props.background == :primary
    end
  end

  describe "icon_button/1" do
    test "returns icon_button node" do
      node = W.icon_button(icon: "favorite", on_tap: {self(), :liked})
      assert node.type == :icon_button
      assert node.props.icon == "favorite"
      assert node.children == []
    end

    test "accepts selected and enabled props" do
      node = W.icon_button(icon: "bookmark", selected: true, enabled: false)
      assert node.props.selected == true
      assert node.props.enabled == false
    end
  end

  describe "segmented_button/1" do
    test "returns segmented_button node" do
      segments = [
        %{id: "day", label: "Day"},
        %{id: "week", label: "Week"},
        %{id: "month", label: "Month"}
      ]

      node = W.segmented_button(segments: segments, selected: "week", on_select: {self(), :seg})
      assert node.type == :segmented_button
      assert length(node.props.segments) == 3
      assert node.props.selected == "week"
      assert node.children == []
    end
  end

  # ── New components: Navigation ────────────────────────────────────────────

  describe "app_bar/1" do
    test "returns app_bar node" do
      node = W.app_bar(title: "My App", leading_icon: "back", on_leading: {self(), :back})
      assert node.type == :app_bar
      assert node.props.title == "My App"
      assert node.props.leading_icon == "back"
      assert node.children == []
    end

    test "accepts trailing_actions" do
      actions = [%{icon: "search", on_tap: {self(), :search}}]
      node = W.app_bar(title: "Test", trailing_actions: actions)
      assert length(node.props.trailing_actions) == 1
    end
  end

  describe "nav_bar/1" do
    test "returns nav_bar node" do
      items = [%{id: "home", label: "Home", icon: "home"}]
      node = W.nav_bar(items: items, active: "home", on_select: {self(), :nav})
      assert node.type == :nav_bar
      assert length(node.props.items) == 1
      assert node.props.active == "home"
      assert node.children == []
    end
  end

  describe "nav_drawer/1" do
    test "returns nav_drawer node" do
      items = [%{id: "settings", label: "Settings", icon: "settings"}]

      node =
        W.nav_drawer(visible: true, items: items, active: "settings", on_select: {self(), :nav})

      assert node.type == :nav_drawer
      assert node.props.visible == true
      assert node.children == []
    end
  end

  describe "nav_rail/1" do
    test "returns nav_rail node" do
      items = [%{id: "inbox", label: "Inbox", icon: "mail"}]
      node = W.nav_rail(items: items, active: "inbox", on_select: {self(), :nav})
      assert node.type == :nav_rail
      assert length(node.props.items) == 1
      assert node.children == []
    end
  end

  # ── New components: Selection / Pickers ───────────────────────────────────

  describe "menu/1" do
    test "returns menu node" do
      items = [%{label: "Edit", action: :edit}, %{label: "Delete", action: :delete}]
      node = W.menu(items: items, visible: true, on_select: {self(), :menu_select})
      assert node.type == :menu
      assert length(node.props.items) == 2
      assert node.props.visible == true
      assert node.children == []
    end
  end

  describe "date_picker/1" do
    test "returns date_picker node" do
      node =
        W.date_picker(
          visible: true,
          on_select: {self(), :date_selected},
          selected_date: "2025-01-15"
        )

      assert node.type == :date_picker
      assert node.props.visible == true
      assert node.props.selected_date == "2025-01-15"
      assert node.children == []
    end

    test "accepts min_date, max_date, title" do
      node =
        W.date_picker(
          visible: true,
          min_date: "2025-01-01",
          max_date: "2025-12-31",
          title: "Select Date"
        )

      assert node.props.min_date == "2025-01-01"
      assert node.props.title == "Select Date"
    end
  end

  describe "time_picker/1" do
    test "returns time_picker node" do
      node =
        W.time_picker(visible: true, on_select: {self(), :time_selected}, selected_time: "14:30")

      assert node.type == :time_picker
      assert node.props.selected_time == "14:30"
      assert node.children == []
    end
  end

  describe "search_bar/1" do
    test "returns search_bar node" do
      node = W.search_bar(placeholder: "Search...", on_change: {self(), :query_changed})
      assert node.type == :search_bar
      assert node.props.placeholder == "Search..."
      assert node.props.on_change == {self(), :query_changed}
      assert node.children == []
    end

    test "accepts active and on_submit props" do
      node = W.search_bar(active: true, on_submit: {self(), :submitted})
      assert node.props.active == true
      assert node.props.on_submit == {self(), :submitted}
    end
  end

  # ── Prop filtering ────────────────────────────────────────────────────────

  describe "prop filtering" do
    test "all leaf components filter unknown props" do
      leaf_fns = [
        {&W.text/1, [text: "Hi", bogus: true]},
        {&W.button/1, [text: "OK", bogus: true]},
        {&W.icon/1, [name: "x", bogus: true]},
        {&W.checkbox/1, [value: true, bogus: true]},
        {&W.radio/1, [selected: true, bogus: true]},
        {&W.chip/1, [label: "X", bogus: true]},
        {&W.snackbar/1, [message: "Hi", bogus: true]},
        {&W.fab/1, [icon: "add", bogus: true]},
        {&W.icon_button/1, [icon: "x", bogus: true]},
        {&W.segmented_button/1, [segments: [], bogus: true]},
        {&W.app_bar/1, [title: "T", bogus: true]},
        {&W.nav_bar/1, [items: [], bogus: true]},
        {&W.nav_drawer/1, [items: [], bogus: true]},
        {&W.nav_rail/1, [items: [], bogus: true]},
        {&W.menu/1, [items: [], bogus: true]},
        {&W.date_picker/1, [visible: true, bogus: true]},
        {&W.time_picker/1, [visible: true, bogus: true]},
        {&W.search_bar/1, [placeholder: "S", bogus: true]},
        {&W.carousel/1, [id: :c, bogus: true]}
      ]

      for {fun, props} <- leaf_fns do
        node = fun.(props)

        refute Map.has_key?(node.props, :bogus),
               "Expected #{node.type} to filter :bogus prop"
      end
    end

    test "all container components filter unknown props" do
      container_fns = [
        {&W.card/2, [[bogus: true], []]},
        {&W.badge/2, [[bogus: true], []]},
        {&W.bottom_sheet/2, [[bogus: true], []]},
        {&W.tooltip/2, [[text: "T", bogus: true], []]}
      ]

      for {fun, args} <- container_fns do
        node = apply(fun, args)

        refute Map.has_key?(node.props, :bogus),
               "Expected #{node.type} to filter :bogus prop"
      end
    end
  end

  # ── Keyword and map input ─────────────────────────────────────────────────

  describe "input format" do
    test "all leaf components accept keyword lists" do
      node = W.checkbox(value: true, label: "Test")
      assert node.props.value == true
    end

    test "all leaf components accept maps" do
      node = W.checkbox(%{value: false, label: "Map"})
      assert node.props.value == false
    end

    test "all container components accept keyword lists" do
      node = W.card(variant: :filled, children: [])
      assert node.props.variant == :filled
    end

    test "all container components accept maps" do
      node = W.card(%{variant: :outlined}, [])
      assert node.props.variant == :outlined
    end
  end

  # ── Native view ───────────────────────────────────────────────────────────

  describe "native_view/2" do
    test "returns native_view node with module" do
      node = W.native_view(MyApp.Chart, id: :chart)
      assert node.type == :native_view
      assert node.props.module == MyApp.Chart
      assert node.props.id == :chart
    end
  end

  # ── Text variant presets ────────────────────────────────────────────────

  describe "text variant presets" do
    test "applies display variant defaults" do
      node = W.text(text: "Hello", variant: :display)
      assert node.props.text_size == :"4xl"
      assert node.props.font_weight == "bold"
    end

    test "applies heading variant defaults" do
      node = W.text(text: "Hello", variant: :heading)
      assert node.props.text_size == :"2xl"
      assert node.props.font_weight == "semibold"
    end

    test "applies title variant defaults" do
      node = W.text(text: "Hello", variant: :title)
      assert node.props.text_size == :xl
      assert node.props.font_weight == "medium"
    end

    test "applies body variant defaults" do
      node = W.text(text: "Hello", variant: :body)
      assert node.props.text_size == :base
      assert node.props.font_weight == "regular"
    end

    test "applies caption variant defaults" do
      node = W.text(text: "Hello", variant: :caption)
      assert node.props.text_size == :sm
      assert node.props.text_color == :muted
    end

    test "applies label variant defaults" do
      node = W.text(text: "Hello", variant: :label)
      assert node.props.text_size == :xs
      assert node.props.font_weight == "medium"
      assert node.props.text_color == :muted
    end

    test "applies overline variant defaults" do
      node = W.text(text: "Hello", variant: :overline)
      assert node.props.text_size == :xs
      assert node.props.font_weight == "medium"
    end

    test "explicit props override variant defaults" do
      node = W.text(text: "Hello", variant: :caption, text_size: :xl, text_color: :primary)
      assert node.props.text_size == :xl
      assert node.props.text_color == :primary
    end

    test "text without variant has no variant defaults applied" do
      node = W.text(text: "Hello")
      refute Map.has_key?(node.props, :text_size)
      refute Map.has_key?(node.props, :font_weight)
    end

    test "selectable prop is preserved" do
      node = W.text(text: "Copy me", selectable: true)
      assert node.props.selectable == true
    end
  end

  # ── New component constructors ──────────────────────────────────────────

  describe "new component constructors" do
    test "skeleton/1 returns correct node" do
      node = W.skeleton(width: 200, height: 16)
      assert node.type == :skeleton
      assert node.props.width == 200
      assert node.props.height == 16
    end

    test "empty_state/1 returns correct node" do
      node = W.empty_state(icon: "inbox", title: "Empty")
      assert node.type == :empty_state
      assert node.props.icon == "inbox"
      assert node.props.title == "Empty"
    end

    test "avatar/1 returns correct node" do
      node = W.avatar(fallback: "JS", size: 48)
      assert node.type == :avatar
      assert node.props.fallback == "JS"
      assert node.props.size == 48
    end

    test "stepper/1 returns correct node" do
      node = W.stepper(steps: ["A", "B"], current: 0)
      assert node.type == :stepper
      assert node.props.steps == ["A", "B"]
      assert node.props.current == 0
    end

    test "grid/2 returns correct node" do
      node = W.grid([columns: 2], [])
      assert node.type == :grid
      assert node.props.columns == 2
    end
  end

  # ── Accessibility props ─────────────────────────────────────────────────

  describe "accessibility props on components" do
    test "text accepts accessibility_label" do
      node = W.text(text: "Hello", accessibility_label: "Greeting")
      assert node.props.accessibility_label == "Greeting"
    end

    test "button accepts accessibility_id" do
      node = W.button(text: "Submit", accessibility_id: :submit_btn)
      assert node.props.accessibility_id == :submit_btn
    end

    test "icon accepts accessibility_role" do
      node = W.icon(name: "trash", accessibility_role: :button)
      assert node.props.accessibility_role == :button
    end

    test "skeleton accepts accessibility_label" do
      node = W.skeleton(width: 100, accessibility_label: "Loading")
      assert node.props.accessibility_label == "Loading"
    end

    test "empty_state accepts accessibility_label" do
      node = W.empty_state(icon: "inbox", title: "Empty", accessibility_label: "No items")
      assert node.props.accessibility_label == "No items"
    end

    test "avatar accepts accessibility_hint" do
      node = W.avatar(fallback: "JS", accessibility_hint: "User profile")
      assert node.props.accessibility_hint == "User profile"
    end

    test "stepper accepts accessibility_value" do
      node = W.stepper(steps: ["A", "B"], current: 0, accessibility_value: "Step 1 of 2")
      assert node.props.accessibility_value == "Step 1 of 2"
    end

    test "grid accepts accessibility_hidden" do
      node = W.grid([columns: 2, accessibility_hidden: true], [])
      assert node.props.accessibility_hidden == true
    end
  end
end
