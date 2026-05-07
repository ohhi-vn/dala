defmodule Dala.App do
  @moduledoc """
  Public API for Dala application functionality.

  This module delegates to `Dala.App.App` for application functionality.
  """

  @doc """
  Defines an application module.
  """
  defmacro __using__(opts) do
    quote do
      use Dala.App.App, unquote(opts)
    end
  end

  @doc """
  Declare a navigation stack.
  """
  @spec stack(atom(), keyword()) :: map()
  defdelegate stack(name, opts), to: Dala.App.App

  @doc """
  Declare a tab bar containing multiple named stacks.
  """
  @spec tab_bar([map()]) :: map()
  defdelegate tab_bar(branches), to: Dala.App.App

  @doc """
  Declare a side drawer containing multiple named stacks.
  """
  @spec drawer([map()]) :: map()
  defdelegate drawer(branches), to: Dala.App.App
end
