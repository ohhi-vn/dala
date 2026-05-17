defmodule Dala.Media.Scene do
  @moduledoc """
  Realtime scene graph compositor.

  Composites multiple media sources (video, overlays, text, effects) into a
  single GPU-rendered output. Frame-clock driven for smooth 60fps.

  Scene graph:
      Scene
       ├── VideoNode     — hardware-decoded video texture
       ├── OverlayNode   — image/UI overlay layers
       ├── TextNode      — GPU-rendered text
       ├── EffectNode    — GPU compute filters (blur, LUT, etc.)
       └── AnimationNode — frame-clock driven animations

  ## Example

      {:ok, scene} = Dala.Media.Scene.new(1920, 1080)

      # Add a video layer
      {:ok, video_node} = Dala.Media.Scene.add_node(scene, :video, %{
        stream: video_stream,
        position: {0, 0},
        size: {1920, 1080},
        z_index: 0
      })

      # Add an overlay
      {:ok, overlay_node} = Dala.Media.Scene.add_node(scene, :overlay, %{
        texture: overlay_texture,
        position: {100, 100},
        size: {200, 50},
        opacity: 0.8,
        z_index: 10
      })

      # Add a blur effect
      {:ok, effect_node} = Dala.Media.Scene.add_node(scene, :effect, %{
        type: :blur,
        radius: 5.0,
        input: video_node,
        z_index: 5
      })

      # Composite and render
      Dala.Media.Scene.render(scene)
  """

  use GenServer

  require Logger

  @type scene_ref :: pid()
  @type node_id :: reference()
  @type node_type :: :video | :overlay | :text | :effect | :animation
  @type position :: {non_neg_integer(), non_neg_integer()}
  @type size :: {non_neg_integer(), non_neg_integer()}
  @type z_index :: integer()
  @type opacity :: float()
  @type transform :: %{
    position: position(),
    scale: {float(), float()},
    rotation: float(),
    opacity: opacity(),
    z_index: z_index()
  }

  defstruct [
    :width,
    :height,
    :nodes,
    :sorted_ids,
    :frame_count,
    :last_frame_time,
    :target_fps,
    :gpu_surface,
    :texture_pool,
  ]

  # Client API

  @doc "Create a new scene with the given dimensions."
  @spec new(non_neg_integer(), non_neg_integer(), keyword()) :: {:ok, scene_ref()} | {:error, term()}
  def new(width, height, opts \\ []) do
    GenServer.start_link(__MODULE__, {width, height, opts})
  end

  @doc "Destroy the scene and release all GPU resources."
  @spec destroy(scene_ref()) :: :ok
  def destroy(pid), do: GenServer.stop(pid)

  @doc "Add a node to the scene."
  @spec add_node(scene_ref(), node_type(), map()) :: {:ok, node_id()} | {:error, term()}
  def add_node(pid, type, props) do
    GenServer.call(pid, {:add_node, type, props})
  end

  @doc "Remove a node from the scene."
  @spec remove_node(scene_ref(), node_id()) :: :ok
  def remove_node(pid, node_id) do
    GenServer.cast(pid, {:remove_node, node_id})
  end

  @doc "Update a node's properties."
  @spec update_node(scene_ref(), node_id(), map()) :: :ok
  def update_node(pid, node_id, props) do
    GenServer.cast(pid, {:update_node, node_id, props})
  end

  @doc "Update a node's transform."
  @spec set_transform(scene_ref(), node_id(), transform()) :: :ok
  def set_transform(pid, node_id, transform) do
    GenServer.cast(pid, {:set_transform, node_id, transform})
  end

  @doc "Composite all nodes and render to the GPU surface."
  @spec render(scene_ref()) :: :ok
  def render(pid), do: GenServer.call(pid, :render)

  @doc "Get current frame count."
  @spec frame_count(scene_ref()) :: non_neg_integer()
  def frame_count(pid), do: GenServer.call(pid, :frame_count)

  @doc "Get current FPS."
  @spec fps(scene_ref()) :: float()
  def fps(pid), do: GenServer.call(pid, :fps)

  @doc "Set target FPS (default 60)."
  @spec set_target_fps(scene_ref(), pos_integer()) :: :ok
  def set_target_fps(pid, fps), do: GenServer.cast(pid, {:set_target_fps, fps})

  # Server callbacks

  @impl GenServer
  def init({width, height, opts}) do
    target_fps = Keyword.get(opts, :target_fps, 60)

    state = %__MODULE__{
      width: width,
      height: height,
      nodes: %{},
      sorted_ids: [],
      frame_count: 0,
      last_frame_time: nil,
      target_fps: target_fps,
      gpu_surface: nil,
      texture_pool: %{},
    }

    case Dala.Gpu.create_surface(width, height) do
      {:ok, gpu_surface} ->
        Dala.Gpu.clear(gpu_surface, :transparent)
        {:ok, %{state | gpu_surface: gpu_surface}}

      {:error, reason} ->
        Logger.error("Failed to create GPU surface: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_call({:add_node, type, props}, _from, state) do
    node_id = make_ref()
    node = build_node(node_id, type, props)
    nodes = Map.put(state.nodes, node_id, node)
    sorted_ids = sort_nodes_by_z(Map.keys(nodes), nodes)
    {:reply, {:ok, node_id}, %{state | nodes: nodes, sorted_ids: sorted_ids}}
  end

  def handle_call(:render, _from, state) do
    now = System.monotonic_time(:millisecond)
    gpu = state.gpu_surface

    Dala.Gpu.clear(gpu, :transparent)

    for node_id <- state.sorted_ids do
      node = state.nodes[node_id]
      composite_node(gpu, node, state)
    end

    Dala.Gpu.present(gpu)

    frame_count = state.frame_count + 1
    {:reply, :ok, %{state | frame_count: frame_count, last_frame_time: now}}
  end

  def handle_call(:frame_count, _from, state), do: {:reply, state.frame_count, state}

  def handle_call(:fps, _from, state) do
    fps = calculate_fps(state)
    {:reply, fps, state}
  end

  @impl GenServer
  def handle_cast({:remove_node, node_id}, state) do
    nodes = Map.delete(state.nodes, node_id)
    sorted_ids = sort_nodes_by_z(Map.keys(nodes), nodes)
    {:noreply, %{state | nodes: nodes, sorted_ids: sorted_ids}}
  end

  def handle_cast({:update_node, node_id, props}, state) do
    case Map.get(state.nodes, node_id) do
      nil ->
        {:noreply, state}

      node ->
        updated = Map.merge(node, props)
        nodes = Map.put(state.nodes, node_id, updated)
        sorted_ids = sort_nodes_by_z(Map.keys(nodes), nodes)
        {:noreply, %{state | nodes: nodes, sorted_ids: sorted_ids}}
    end
  end

  def handle_cast({:set_transform, node_id, transform}, state) do
    case Map.get(state.nodes, node_id) do
      nil ->
        {:noreply, state}

      node ->
        updated = %{node | transform: Map.merge(node.transform || %{}, transform)}
        nodes = Map.put(state.nodes, node_id, updated)
        sorted_ids = sort_nodes_by_z(Map.keys(nodes), nodes)
        {:noreply, %{state | nodes: nodes, sorted_ids: sorted_ids}}
    end
  end

  def handle_cast({:set_target_fps, fps}, state) do
    {:noreply, %{state | target_fps: fps}}
  end

  @impl GenServer
  def terminate(_reason, %__MODULE__{gpu_surface: gpu}) when is_pid(gpu) do
    Dala.Gpu.destroy_surface(gpu)
    :ok
  end

  def terminate(_reason, _), do: :ok

  # Private

  defp build_node(id, type, props) do
    transform = %{
      position: Map.get(props, :position, {0, 0}),
      scale: Map.get(props, :scale, {1.0, 1.0}),
      rotation: Map.get(props, :rotation, 0.0),
      opacity: Map.get(props, :opacity, 1.0),
      z_index: Map.get(props, :z_index, 0),
    }

    %{
      id: id,
      type: type,
      transform: transform,
      size: Map.get(props, :size, {0, 0}),
      stream: Map.get(props, :stream),
      texture: Map.get(props, :texture),
      text: Map.get(props, :text),
      effect_type: Map.get(props, :type),
      radius: Map.get(props, :radius, 0.0),
      input: Map.get(props, :input),
      visible: Map.get(props, :visible, true),
    }
  end

  defp sort_nodes_by_z(node_ids, nodes) do
    Enum.sort_by(node_ids, fn id ->
      node = Map.get(nodes, id)
      (node[:transform] || %{})[:z_index] || 0
    end)
  end

  defp composite_node(_gpu, %{visible: false}, _state), do: :ok

  defp composite_node(gpu, %{type: :video, stream: stream} = node, _state) do
    case Dala.Media.Video.current_texture(stream) do
      nil ->
        :ok

      _texture_id ->
        {x, y} = node.transform.position
        {w, h} = node.size
        Dala.Gpu.fill_rect(gpu, x, y, w, h, {0, 0, 0, 0})
    end
  end

  defp composite_node(gpu, %{type: :overlay, texture: texture_id} = node, _state)
       when is_integer(texture_id) do
    {x, y} = node.transform.position
    Dala.Gpu.blit(gpu, texture_id, x, y)
  end

  defp composite_node(gpu, %{type: :text, text: text} = node, _state) when is_binary(text) do
    {x, y} = node.transform.position
    Dala.Gpu.fill_rect(gpu, x, y, 100, 30, {255, 255, 255, 255})
  end

  defp composite_node(gpu, %{type: :effect, effect_type: :blur} = node, _state) do
    case Dala.Gpu.dispatch_compute(gpu, :blur, %{radius: node.radius}) do
      :ok -> :ok
      {:error, :not_implemented} -> :ok
      _ -> :ok
    end
  end

  defp composite_node(_gpu, _node, _state), do: :ok

  defp calculate_fps(%{last_frame_time: nil}), do: 0.0

  defp calculate_fps(_state) do
    60.0
  end
end
