defmodule Dala.Node do
  @moduledoc """
  Structured representation of a UI node in the Dala framework.

  This is a public API wrapper around `Dala.Ui.Node`. The struct definition
  mirrors `Dala.Ui.Node` so that `%Dala.Node{}` and `%Dala.Ui.Node{}`
  are compatible.

  ## Fields

    * `:id` — Stable identity for diffing (required for proper reconciliation)
    * `:type` — Atom indicating the component type (`:text`, `:button`, `:column`, etc.)
    * `:props` — Map of component-specific properties
    * `:children` — List of child `Dala.Node` structs

  ## Example

      %Dala.Node{
        id: "root",
        type: :column,
        props: %{padding: :md},
        children: [
          %Dala.Node{id: "t1", type: :text, props: %{text: "Hello"}},
          %Dala.Node{id: "b1", type: :button, props: %{title: "Click"}}
        ]
      }
  """

  @type t :: %__MODULE__{
          id: String.t() | atom(),
          type: atom(),
          props: map(),
          children: [t()]
        }

  defstruct [
    :id,
    :type,
    props: %{},  
    children: []
  ]

  @doc """
  Creates a node struct from a map representation.

  The map should have `:type` and `:props` keys. Optionally `:id` and `:children`.
  If `:id` is not provided, it will be generated from the parent id and child index.
  """
  @spec from_map(map(), String.t()) :: t()
  def from_map(map, default_id) do
    Dala.Ui.Node.from_map(map, default_id)
  end

  @doc """
  Converts a node to a map.
  """
  @spec to_map(t()) :: map()
  def to_map(node) do
    Dala.Ui.Node.to_map(node)
  end
end
