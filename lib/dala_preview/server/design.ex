defmodule DalaPreview.Server.Design do
  @moduledoc "Design state management"

  defstruct nodes: [], next_id: 0

  def new() do
    %__MODULE__{}
  end

  def add_node(%__MODULE__{nodes: nodes, next_id: next_id} = design, node) do
    node_with_id = Map.put(node, :id, next_id)
    %{design | nodes: [node_with_id | nodes], next_id: next_id + 1}
  end

  def update_node_property(%__MODULE__{nodes: nodes} = design, node_id, property, value) do
    updated_nodes =
      Enum.map(nodes, fn node ->
        if node.id == node_id do
          Map.put(node, property, value)
        else
          node
        end
      end)

    %{design | nodes: updated_nodes}
  end

  def delete_node(%__MODULE__{nodes: nodes} = design, node_id) do
    updated_nodes = Enum.reject(nodes, fn node -> node.id == node_id end)
    %{design | nodes: updated_nodes}
  end

  def move_node(%__MODULE__{nodes: nodes} = design, node_id, new_index, _context \\ nil) do
    case Enum.split_with(nodes, fn node -> node.id == node_id end) do
      {[node_to_move], other_nodes} ->
        {left, right} = Enum.split(other_nodes, new_index)
        %{design | nodes: left ++ [node_to_move | right]}

      _ ->
        design
    end
  end
end
