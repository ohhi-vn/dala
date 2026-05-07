defmodule Dala.Ui.Diff do
  @moduledoc """
  Diff engine for incremental UI updates.

  Compares two UI trees (as `Dala.Ui.Node` structs) and produces a minimal
  set of patches to transform the old tree into the new tree.

  ## Patch format

  Patches are tuples tagged with an action:

      {:replace, id, node}           # Replace entire node
      {:update_props, id, props}     # Update props on existing node
      {:insert, parent_id, index, node}  # Insert new node
      {:remove, id}                  # Remove node

  ## Usage

      old_tree = Dala.Ui.Node.from_map(old_map, "root")
      new_tree = Dala.Ui.Node.from_map(new_map, "root")
      patches = Dala.Ui.Diff.diff(old_tree, new_tree)

  ## Node identity

  Nodes are identified by the `:id` field in `Dala.Ui.Node`. This must be
  stable across renders for proper reconciliation.
  """

  @type node_id :: String.t() | atom()

  @type patch ::
          {:replace, node_id(), Dala.Ui.Node.t()}
          | {:update_props, node_id(), map()}
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

  # Props diff - send full props when changed
  defp diff_props(%Dala.Ui.Node{id: id, props: old_props}, %Dala.Ui.Node{props: new_props}) do
    if old_props == new_props do
      []
    else
      [{:update_props, id, new_props}]
    end
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
