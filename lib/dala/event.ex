defmodule Dala.Event do
  @moduledoc """
  Convenience module that re-exports the unified event emission API.

  This module delegates all functions to `Dala.Event.Event`, providing a
  shorter and more ergonomic API:

      # Instead of:
      Dala.Event.Event.dispatch(pid, addr, event, payload)

      # You can write:
      Dala.Event.dispatch(pid, addr, event, payload)

  See `Dala.Event.Event` for full documentation.
  """

  alias Dala.Event.Event

  @doc "See `Dala.Event.Event.emit/4`"
  defdelegate emit(addr, event, payload, target, scope), to: Event

  @doc "See `Dala.Event.Event.dispatch/4`"
  defdelegate dispatch(pid, addr, event, payload), to: Event

  @doc "See `Dala.Event.Event.is_event?/1`"
  defdelegate is_event?(msg), to: Event

  @doc "See `Dala.Event.Event.match_address?/2`"
  defdelegate match_address?(addr, filters), to: Event

  @doc "See `Dala.Event.Event.send_test/6` and `Dala.Event.Event.send_test/7`"
  defdelegate send_test(pid, screen, widget, id, event, payload \\ nil, opts \\ []), to: Event
end
