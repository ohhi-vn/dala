defmodule Dala.Ui.Diff do
  import Bitwise

  @moduledoc """
  Diff engine for incremental UI updates.

  Compares two UI trees (as `Dala.Ui.Node` structs) and produces a minimal
  set of patches to transform the old tree into the new tree.

  ## Patch format

  Patches are tuples tagged with an action:

      {:replace, id, node}           # Replace entire node
      {:update_props, id, props}     # Update props on existing node (full replacement)
      {:patch_node, id, mask, props}  # Patch only changed fields (field-mask based)
      {:insert, parent_id, index, node}  # Insert new node
      {:remove, id}                  # Remove node

  ## Usage

      old_tree = Dala.Ui.Node.from_map(old_map, "root")
      new_tree = Dala.Ui.Node.from_map(new_map, "root")
      patches = Dala.Ui.Diff.diff(old_tree, new_tree)

  ## Node identity

  Nodes are identified by the `:id` field in `Dala.Ui.Node`. This must be
  stable across renders for proper reconciliation.

  ## Field masks

  When only a few props change, `{:patch_node, id, mask, props}` is emitted
  instead of `{:update_props, id, props}`. The mask is a 16-bit bitmask
  where bit N corresponds to field tag (N+1). If more than half the fields
  changed, a full `{:update_props, ...}` is sent instead.
  """

  # Mapping from prop keys to field mask bits
  @field_mask_bits %{
    text: 0x0001,
    title: 0x0002,
    color: 0x0004,
    background: 0x0008,
    on_tap: 0x0010,
    width: 0x0020,
    height: 0x0040,
    padding: 0x0080,
    flex_grow: 0x0100,
    flex_direction: 0x0200,
    justify_content: 0x0400,
    align_items: 0x0800
  }

  # Known prop keys that participate in field masks
  @known_props [
    :text,
    :title,
    :color,
    :background,
    :on_tap,
    :width,
    :height,
    :padding,
    :flex_grow,
    :flex_direction,
    :justify_content,
    :align_items
  ]

  @type node_id :: String.t() | atom()

  @type patch ::
          {:replace, node_id(), Dala.Ui.Node.t()}
          | {:update_props, node_id(), map()}
          | {:patch_node, node_id(), non_neg_integer(), map()}
          | {:insert, node_id(), non_neg_integer(), Dala.Ui.Node.t()}
          | {:remove, node_id()}

  @doc """
  Compute the diff between two UI trees.

  Returns a list of patches to transform `old_tree` into `new_tree`.
  """
  @spec diff(Dala.Ui.Node.t() | nil, Dala.Ui.Node.t() | nil) :: [patch()]
  def diff(nil, %Dala.Ui.Node{id: id} = new), do: [{:replace, id, new}]
  def diff(%Dala.Ui.Node{id: id}, nil), do: [{:remove, id}]
  def diff(%Dala.Ui.Node{id: id} = old, %Dala.Ui.Node{id: id} = new), do: do_diff(old, new)

  def diff(%Dala.Ui.Node{id: old_id} = _old, %Dala.Ui.Node{id: new_id} = new) do
    # Different IDs at root level - full replacement
    [{:remove, old_id}, {:insert, :root, 0, %Dala.Ui.Node{new | id: new_id}}]
  end

  # Same node - check for changes
  defp do_diff(%Dala.Ui.Node{id: _id, type: type} = old, %Dala.Ui.Node{type: type} = new) do
    props_patches = diff_props(old, new)
    children_patches = diff_children(old, new)
    props_patches ++ children_patches
  end

  defp do_diff(%Dala.Ui.Node{id: id} = _old, %Dala.Ui.Node{} = new) do
    # Different type - full replacement
    [{:replace, id, new}]
  end

  # Props diff - use field-mask based patching when few fields changed,
  # full update when many fields changed
  defp diff_props(%Dala.Ui.Node{id: id, props: old_props}, %Dala.Ui.Node{props: new_props}) do
    if old_props == new_props do
      []
    else
      {mask, changed} = compute_field_mask(old_props, new_props)
      known_count = Enum.count(@known_props, &Map.has_key?(new_props, &1))
      changed_count = map_size(changed)

      # If more than half the known fields changed, send full update
      if known_count > 0 and changed_count > known_count / 2 do
        [{:update_props, id, new_props}]
      else
        [{:patch_node, id, mask, changed}]
      end
    end
  end

  @doc """
  Compute a field mask and changed props map from old and new props.

  Returns a `{mask, changed_map}` tuple where `mask` is a 16-bit bitmask
  and `changed_map` contains only the props that differ.
  """
  @spec compute_field_mask(map(), map()) :: {non_neg_integer(), map()}
  def compute_field_mask(old_props, new_props) when is_map(old_props) and is_map(new_props) do
    all_keys = MapSet.union(MapSet.new(Map.keys(old_props)), MapSet.new(Map.keys(new_props)))

    Enum.reduce(all_keys, {0, %{}}, fn key, {mask, changed} ->
      old_val = Map.get(old_props, key)
      new_val = Map.get(new_props, key)

      if old_val != new_val do
        bit = Map.get(@field_mask_bits, key, 0)

        if bit != 0 do
          {mask ||| bit, Map.put(changed, key, new_val)}
        else
          # Unknown prop key — include in changed map but no mask bit
          {mask, Map.put(changed, key, new_val)}
        end
      else
        {mask, changed}
      end
    end)
  end

  # Children diff with keyed reconciliation
  defp diff_children(%Dala.Ui.Node{id: parent_id, children: old_children}, %Dala.Ui.Node{
         children: new_children
       }) do
    old_map = Map.new(old_children, &{&1.id, &1})
    new_map = Map.new(new_children, &{&1.id, &1})

    []
    |> diff_removed(old_map, new_map)
    |> diff_inserted(parent_id, old_map, new_children)
    |> diff_existing(old_map, new_map)
  end

  # Remove nodes that are in old but not in new
  defp diff_removed(patches, old_map, new_map) do
    Enum.reduce(old_map, patches, fn {id, _old_node}, acc ->
      if Map.has_key?(new_map, id) do
        acc
      else
        [{:remove, id} | acc]
      end
    end)
  end

  # Insert new nodes with correct index
  defp diff_inserted(patches, parent_id, old_map, new_children) do
    Enum.with_index(new_children)
    |> Enum.reduce(patches, fn {child, index}, acc ->
      if Map.has_key?(old_map, child.id) do
        acc
      else
        [{:insert, parent_id, index, child} | acc]
      end
    end)
  end

  # Diff existing nodes recursively
  defp diff_existing(patches, old_map, new_map) do
    Enum.reduce(new_map, patches, fn {id, new_node}, acc ->
      case Map.get(old_map, id) do
        nil ->
          acc

        old_node ->
          acc ++ diff(old_node, new_node)
      end
    end)
  end
end
