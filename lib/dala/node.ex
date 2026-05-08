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
  Convert a node struct back to a map representation.
  """
  @spec to_map(t()) :: map()
  def to_map(node) do
    Dala.Ui.Node.to_map(node)
  end

  @doc """
  Compute a stable numeric u64 ID by hashing the string/atom ID.

  Uses SHA-256 and takes the first 8 bytes as a big-endian unsigned 64-bit integer.
  This matches the `hash_id` function in `Dala.Ui.Renderer`.
  """
  @spec stable_id(String.t() | atom()) :: non_neg_integer()
  def stable_id(id) do
    id_str = to_string(id)
    <<hash::unsigned-64-big, _rest::binary>> = :crypto.hash(:sha256, id_str)
    hash
  end

  @doc """
  Compute the layout hash for a node.

  The layout hash is computed from the node type, layout-relevant props
  (width, height, padding, flex_grow, flex_direction, justify_content, align_items),
  and the number of children. Uses SHA-256 and takes the first 8 bytes as
  a big-endian unsigned 64-bit integer.
  """
  @spec compute_layout_hash(t()) :: non_neg_integer()
  def compute_layout_hash(%__MODULE__{type: type, props: props, children: children}) do
    layout_props = [
      to_string(type),
      format_layout_prop(:width, props),
      format_layout_prop(:height, props),
      format_layout_prop(:padding, props),
      format_layout_prop(:flex_grow, props),
      format_layout_prop(:flex_direction, props),
      format_layout_prop(:justify_content, props),
      format_layout_prop(:align_items, props),
      to_string(length(children))
    ]

    data = Enum.join(layout_props, "|")
    <<hash::unsigned-64-big, _rest::binary>> = :crypto.hash(:sha256, data)
    hash
  end

  defp format_layout_prop(key, props) do
    case Map.get(props, key) do
      nil -> ""
      val -> to_string(val)
    end
  end
end
