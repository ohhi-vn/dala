defmodule DemoApp.FormsScreen do
  @moduledoc """
  Forms screen demonstrating various input components and validation.
  """
  use Dala.Spark.Dsl

  dala do
    attribute :username, :string, default: ""
    attribute :password, :string, default: ""
    attribute :bio, :string, default: ""
    attribute :age, :integer, default: 25
    attribute :agree_terms, :boolean, default: false
    attribute :errors, :map, default: %{}

    screen name: :forms do
      scroll padding: 16, gap: 16 do
        text "Registration Form", text_size: :xl, weight: :bold
        text "Fill out the form below", text_size: :sm, color: "#666"
        divider()

        # Username
        text "Username", weight: :bold
        text_field value: @username, placeholder: "Enter username", on_change: :update_username
        error_text(Map.get(@errors, :username))

        # Password
        text "Password", weight: :bold
        text_field value: @password, placeholder: "Enter password", secure: true, on_change: :update_password
        error_text(Map.get(@errors, :password))

        # Age slider
        text "Age: @age", weight: :bold
        slider value: @age, min_value: 18, max_value: 100, on_change: :update_age

        # Bio
        text "Bio", weight: :bold
        text_field value: @bio, placeholder: "Tell us about yourself", multiline: true, rows: 4, on_change: :update_bio

        divider()

        # Terms agreement
        row spacing: 12, align: :center do
          toggle value: @agree_terms, on_change: :toggle_terms
          text "I agree to the terms and conditions", flex: 1
        end
        error_text(Map.get(@errors, :terms))

        spacer size: 20

        # Submit button
        button "Submit", on_tap: :submit, background: "#4A90E2", text_color: "#ffffff"
      end
    end
  end

  defp error_text(nil), do: spacer(size: 0)
  defp error_text(msg), do: text(msg, color: "#ff0000", text_size: :sm)

  def handle_event(:update_username, %{"value" => value}, socket) do
    {:noreply, Dala.Socket.assign(socket, :username, value)}
  end

  def handle_event(:update_password, %{"value" => value}, socket) do
    {:noreply, Dala.Socket.assign(socket, :password, value)}
  end

  def handle_event(:update_age, %{"value" => value}, socket) do
    {:noreply, Dala.Socket.assign(socket, :age, value)}
  end

  def handle_event(:update_bio, %{"value" => value}, socket) do
    {:noreply, Dala.Socket.assign(socket, :bio, value)}
  end

  def handle_event(:toggle_terms, %{"value" => value}, socket) do
    {:noreply, Dala.Socket.assign(socket, :agree_terms, value)}
  end

  def handle_event(:submit, _params, socket) do
    errors = validate_form(socket.assigns)

    if map_size(errors) == 0 do
      {:noreply, Dala.Socket.assign(socket, :errors, %{})}
    else
      {:noreply, Dala.Socket.assign(socket, :errors, errors)}
    end
  end

  defp validate_form(assigns) do
    errors = %{}

    errors =
      if assigns.username == "" do
        Map.put(errors, :username, "Username is required")
      else
        errors
      end

    errors =
      if assigns.password == "" do
        Map.put(errors, :password, "Password is required")
      else
        errors
      end

    errors =
      if not assigns.agree_terms do
        Map.put(errors, :terms, "You must agree to terms")
      else
        errors
      end

    errors
  end
end
