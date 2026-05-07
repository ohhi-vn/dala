defmodule Dala.Diff do
  @moduledoc """
  Public API for diff operations.

  This module delegates to `Dala.Ui.Diff` for computing UI tree diffs.
  """

  alias Dala.Ui.Diff

  @type node_id :: String.t() | atom()
  @type patch ::
          {:replace, node_id(), Dala.Node.t()}
          | {:update_props, node_id(), map()}
          | {:insert, node_id(), non_neg_integer(), Dala.Node.t()}
          | {:remove, node_id()}

  @doc """
  Compute the diff between two UI trees.

  Returns a list of patches to transform `old_tree` into `new_tree`.

  ## Examples

      old_tree = Dala.Node.from_map(%{id: "root", type: :text, props: %{text: "Hello"}}, "root")
      new_tree = Dala.Node.from_map(%{id: "root", type: :text, props: %{text: "World"}}, "root")
      patches = Dala.Diff.diff(old_tree, new_tree)

  """
  @spec diff(Dala.Node.t() | nil, Dala.Node.t() | nil) :: [patch()]
  def diff(nil, nil), do: []
  def diff(nil, %Dala.Node{} = new), do: Diff.diff(nil, to_ui_node(new)) |> from_ui_patches()
  def diff(%Dala.Node{} = old, nil), do: Diff.diff(to_ui_node(old), nil) |> from_ui_patches()
  def diff(%Dala.Node{} = old, %Dala.Node{} = new), do: Diff.diff(to_ui_node(old), to_ui_node(new)) |> from_ui_patches()

  defp to_ui_node(%Dala.Node{} = node) do
    %Dala.Ui.Node{
      id: node.id,
      type: node.type,
      props: node.props,
      children: Enum.map(node.children, &to_ui_node/1)
    }
  end
  defp to_ui_node(nil), do: nil

  defp from_ui_patches(patches) do
    Enum.map(patches, fn
      {:replace, id, %Dala.Ui.Node{} = node} -> {:replace, id, from_ui_node(node)}
      {:update_props, id, props} -> {:update_props, id, props}
      {:insert, parent_id, index, %Dala.Ui.Node{} = node} -> {:insert, parent_id, index, from_ui_node(node)}
      {:remove, id} -> {:remove, id}
    end)
  end

  defp from_ui_node(%Dala.Ui.Node{} = node) do
    %Dala.Node{
      id: node.id,
      type: node.type,
      props: node.props,
      children: Enum.map(node.children, &from_ui_node/1)
    }
  end
end
