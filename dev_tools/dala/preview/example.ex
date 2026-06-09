defmodule Dala.Designer.Example do
  @moduledoc """
  Example UI trees for Dala Designer demonstration.

  Each function returns a different sample UI tree showcasing
  various Dala components and layout patterns.
  """

  @doc """
  Full demo tree with various components.
  """
  def ui_tree do
    %{
      type: :column,
      props: %{padding: :space_md, gap: :space_sm},
      children: [
        %{
          type: :text,
          props: %{text: "Dala Designer Example", text_size: :xl, text_color: :primary},
          children: []
        },
        %{
          type: :text,
          props: %{text: "This is a demonstration of the designer system."},
          children: []
        },
        %{type: :divider, props: %{}, children: []},
        %{
          type: :row,
          props: %{gap: :space_sm},
          children: [
            %{type: :button, props: %{text: "Tap Me", on_tap: :button_tapped}, children: []},
            %{
              type: :button,
              props: %{text: "Another Button", on_tap: :other_button},
              children: []
            }
          ]
        },
        %{
          type: :text_field,
          props: %{placeholder: "Type something...", on_change: :text_changed},
          children: []
        },
        %{type: :toggle, props: %{on_tap: :toggle_changed}, children: []},
        %{type: :slider, props: %{value: 50, on_change: :slider_changed}, children: []},
        %{
          type: :list,
          props: %{},
          children: [
            %{
              type: :list_item,
              props: %{on_tap: :item_1},
              children: [%{type: :text, props: %{text: "List Item 1"}, children: []}]
            },
            %{
              type: :list_item,
              props: %{on_tap: :item_2},
              children: [%{type: :text, props: %{text: "List Item 2"}, children: []}]
            },
            %{
              type: :list_item,
              props: %{on_tap: :item_3},
              children: [%{type: :text, props: %{text: "List Item 3"}, children: []}]
            }
          ]
        }
      ]
    }
  end

  @doc """
  A login screen layout.
  """
  def login_screen do
    %{
      type: :column,
      props: %{padding: :space_lg, gap: :space_md},
      children: [
        %{
          type: :text,
          props: %{text: "Welcome Back", text_size: :xl, font_weight: :bold},
          children: []
        },
        %{
          type: :text_field,
          props: %{placeholder: "Email", on_change: :email_changed},
          children: []
        },
        %{
          type: :text_field,
          props: %{placeholder: "Password", on_change: :password_changed},
          children: []
        },
        %{
          type: :button,
          props: %{text: "Sign In", on_tap: :sign_in, fill_width: true},
          children: []
        },
        %{
          type: :row,
          props: %{gap: :space_sm},
          children: [
            %{
              type: :text,
              props: %{text: "Forgot password?", text_color: :primary},
              children: []
            },
            %{type: :spacer, props: %{}, children: []},
            %{type: :text, props: %{text: "Sign Up", text_color: :primary}, children: []}
          ]
        }
      ]
    }
  end

  @doc """
  A settings screen layout.
  """
  def settings_screen do
    %{
      type: :column,
      props: %{padding: :space_md, gap: :space_sm},
      children: [
        %{
          type: :row,
          props: %{gap: :space_sm, padding: :space_sm},
          children: [
            %{type: :icon, props: %{name: :settings, text_size: 24}, children: []},
            %{
              type: :text,
              props: %{text: "Settings", text_size: :xl, font_weight: :bold},
              children: []
            }
          ]
        },
        %{type: :divider, props: %{}, children: []},
        %{
          type: :row,
          props: %{gap: :space_sm, padding: :space_sm},
          children: [
            %{type: :text, props: %{text: "Notifications", fill_width: true}, children: []},
            %{type: :toggle, props: %{on_tap: :notifications_toggled}, children: []}
          ]
        },
        %{
          type: :row,
          props: %{gap: :space_sm, padding: :space_sm},
          children: [
            %{type: :text, props: %{text: "Dark Mode", fill_width: true}, children: []},
            %{type: :toggle, props: %{on_tap: :dark_mode_toggled}, children: []}
          ]
        },
        %{
          type: :row,
          props: %{gap: :space_sm, padding: :space_sm},
          children: [
            %{type: :text, props: %{text: "Volume", fill_width: true}, children: []},
            %{type: :slider, props: %{value: 75, on_change: :volume_changed}, children: []}
          ]
        },
        %{type: :divider, props: %{}, children: []},
        %{
          type: :button,
          props: %{text: "Sign Out", on_tap: :sign_out, fill_width: true},
          children: []
        }
      ]
    }
  end
end
