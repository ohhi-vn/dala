defmodule Dala.Node do
  @moduledoc """
  Structured representation of a UI node in the Dala framework.

  Using a struct instead of raw maps provides:
  - Compile-time verification of field names
  - Default values for optional fields
  - Clear documentation of the node structure

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
  Create a new Node struct from a map.

  Converts the map representation (used by Dala.Ui.Widgets functions) to a proper Node struct.
  Generates an ID if not present.

  ## Example

      Dala.Node.from_map(%{
        type: :text,
        props: %{text: "Hello"},
        children: []
      }, "parent:0")

  """
  @spec from_map(map(), String.t()) :: t()
  def from_map(%{type: type} = map, default_id) do
    id = map[:id] || Map.get(map, :props, %{})[:id] || default_id

    children =
      Map.get(map, :children, [])
      |> Enum.with_index()
      |> Enum.map(fn {child, idx} ->
        from_map(child, "#{id}:#{idx}")
      end)

    %__MODULE__{
      id: id,
      type: type,
      props: Map.get(map, :props, %{}),
      children: children
    }
  end

  @doc """
  Convert a Node struct back to a map representation.

  This is used before sending to the renderer/native side.
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{id: id, type: type, props: props, children: children}) do
    %{
      type: type,
      props: Map.put(props, :id, id),
      children: Enum.map(children, &to_map/1)
    }
  end

  @doc """
  Compute a stable numeric u64 ID by hashing the string/atom ID.

  Uses SHA-256 and takes the first 8 bytes as a big-endian unsigned 64-bit integer.
  Results are cached in an ETS table so repeated lookups for the same ID
  (which is the common case across renders) are O(1) map reads instead of
  full SHA-256 computation.
  """
  @spec stable_id(String.t() | atom()) :: non_neg_integer()
  def stable_id(id) do
    id_str = to_string(id)
    case :ets.lookup(:dala_id_cache, id_str) do
      [{^id_str, hash}] -> hash
      [] ->
        hash = compute_sha256_u64(id_str)
        :ets.insert(:dala_id_cache, {id_str, hash})
        hash
    end
  end

  @doc false
  @spec init_id_cache() :: :ok
  def init_id_cache do
    case :ets.whereis(:dala_id_cache) do
      :undefined ->
        :ets.new(:dala_id_cache, [:set, :public, :named_table, read_concurrency: true])
      _ ->
        :ok
    end
    :ok
  end

  @doc false
  @spec clear_id_cache() :: :ok
  def clear_id_cache do
    case :ets.whereis(:dala_id_cache) do
      :undefined -> :ok
      _ ->
        :ets.delete_all_objects(:dala_id_cache)
        :ok
    end
  end

  defp compute_sha256_u64(data) when is_binary(data) do
    <<hash::unsigned-64-big, _rest::binary>> = :crypto.hash(:sha256, data)
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
