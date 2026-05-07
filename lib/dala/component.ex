defmodule Dala.Component do
  @moduledoc """
  Public API for native view components.

  This module delegates to `Dala.Ui.NativeView` for the component behaviour
  and tree expansion logic.
  """

  alias Dala.Ui.NativeView

  @doc """
  Walk a node tree, expanding `:native_view` nodes into serialisable form.
  """
  @spec expand(map(), pid(), atom()) :: {map(), MapSet.t()}
  defdelegate expand(tree, screen_pid, platform), to: NativeView
end
