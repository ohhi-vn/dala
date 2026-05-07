defmodule Dala.Renderer do
  @moduledoc """
  Public API for rendering operations.

  This module delegates to `Dala.Ui.Renderer` for rendering UI trees.
  """

  alias Dala.Ui.Renderer

  @default_nif Dala.Platform.Native

  @doc """
  Render a UI tree for the given platform.
  """
  @spec render(Dala.Node.t() | map(), atom(), term(), atom()) ::
          {:ok, [Dala.Diff.patch()]} | {:error, term()}
  def render(tree, platform, nif \\ @default_nif, transition \\ :none)

  def render(%Dala.Node{} = tree, platform, nif, transition) do
    tree
    |> to_ui_node()
    |> Renderer.render(platform, nif, transition)
  end

  def render(tree, platform, nif, transition) when is_map(tree) do
    Renderer.render(tree, platform, nif, transition)
  end

  @doc """
  Fast render path for simple updates.
  """
  @spec render_fast(Dala.Node.t() | map(), atom(), term(), atom()) ::
          {:ok, [Dala.Diff.patch()]} | {:error, term()}
  def render_fast(tree, platform, nif \\ @default_nif, transition \\ :none)

  def render_fast(%Dala.Node{} = tree, platform, nif, transition) do
    tree
    |> to_ui_node()
    |> Renderer.render_fast(platform, nif, transition)
  end

  def render_fast(tree, platform, nif, transition) when is_map(tree) do
    Renderer.render_fast(tree, platform, nif, transition)
  end

  @doc """
  Compute patches between old and new trees.
  """
  @spec render_patches(Dala.Node.t() | map() | nil, Dala.Node.t() | map(), atom(), term(), atom()) ::
          {:ok, [Dala.Diff.patch()]} | {:error, term()}
  def render_patches(old_tree, new_tree, platform, nif \\ @default_nif, transition \\ :none)

  def render_patches(old_tree, new_tree, platform, nif, transition)
      when (is_map(old_tree) or is_nil(old_tree)) and is_map(new_tree) do
    Renderer.render_patches(old_tree, new_tree, platform, nif, transition)
  end

  def render_patches(%Dala.Node{} = old_tree, %Dala.Node{} = new_tree, platform, nif, transition) do
    Renderer.render_patches(to_ui_node(old_tree), to_ui_node(new_tree), platform, nif, transition)
  end

  def render_patches(nil, %Dala.Node{} = new_tree, platform, nif, transition) do
    Renderer.render_patches(nil, to_ui_node(new_tree), platform, nif, transition)
  end

  @doc """
  Encode patches to binary frame format for the native side.
  """
  @spec encode_frame([Dala.Diff.patch()]) :: binary()
  def encode_frame(patches) do
    ui_patches = Enum.map(patches, &to_ui_patch/1)
    Renderer.encode_frame(ui_patches)
  end

  @doc """
  Get available colors from theme.
  """
  @spec colors() :: map()
  defdelegate colors(), to: Renderer

  @doc """
  Get text sizes from theme.
  """
  @spec text_sizes() :: map()
  defdelegate text_sizes(), to: Renderer

  defp to_ui_patch({:replace, id, %Dala.Node{} = node}) do
    {:replace, id, to_ui_node(node)}
  end

  defp to_ui_patch({:update_props, id, props}) do
    {:update_props, id, props}
  end

  defp to_ui_patch({:insert, parent_id, index, %Dala.Node{} = node}) do
    {:insert, parent_id, index, to_ui_node(node)}
  end

  defp to_ui_patch({:remove, id}) do
    {:remove, id}
  end

  defp to_ui_node(%Dala.Node{} = node) do
    %Dala.Ui.Node{
      id: node.id,
      type: node.type,
      props: node.props,
      children: Enum.map(node.children, &to_ui_node/1)
    }
  end
end
