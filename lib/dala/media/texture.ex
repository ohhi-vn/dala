defmodule Dala.Media.Texture do
  @moduledoc """
  GPU texture pool to avoid constant allocation/deallocation.

  Pre-allocates a pool of GPU textures and recycles them. Critical for
  avoiding stutter and memory fragmentation during video playback.

  ## Example

      {:ok, pool} = Dala.Media.Texture.new_pool(1920, 1088, count: 8)

      # Acquire a texture (blocks if none available)
      texture_id = Dala.Media.Texture.acquire(pool)

      # Use the texture...
      Dala.Gpu.blit(surface, texture_id, 0, 0)

      # Release back to pool
      Dala.Media.Texture.release(pool, texture_id)
  """

  use GenServer

  require Logger

  @type pool_ref :: pid()
  @type texture_id :: non_neg_integer()

  defstruct [
    :width,
    :height,
    :pool_size,
    :available,
    :in_use,
    :texture_map,
  ]

  # Client API

  @doc "Create a texture pool with the given dimensions."
  @spec new_pool(non_neg_integer(), non_neg_integer(), keyword()) :: {:ok, pool_ref()} | {:error, term()}
  def new_pool(width, height, opts \\ []) do
    GenServer.start_link(__MODULE__, {width, height, opts})
  end

  @doc "Destroy the pool and release all textures."
  @spec destroy_pool(pool_ref()) :: :ok
  def destroy_pool(pid), do: GenServer.stop(pid)

  @doc "Acquire a texture from the pool. Returns texture_id."
  @spec acquire(pool_ref(), timeout()) :: texture_id() | nil
  def acquire(pid, timeout \\ 5000) do
    GenServer.call(pid, :acquire, timeout)
  end

  @doc "Release a texture back to the pool."
  @spec release(pool_ref(), texture_id()) :: :ok
  def release(pid, texture_id) do
    GenServer.cast(pid, {:release, texture_id})
  end

  @doc "Get pool statistics."
  @spec stats(pool_ref()) :: %{available: non_neg_integer(), in_use: non_neg_integer(), total: non_neg_integer()}
  def stats(pid), do: GenServer.call(pid, :stats)

  # Server callbacks

  @impl GenServer
  def init({width, height, opts}) do
    count = Keyword.get(opts, :count, 6)
    format = Keyword.get(opts, :format, :rgba8)

    {available, texture_map} =
      Enum.reduce(1..count, {[], %{}}, fn _id, {avail, map} ->
        case Dala.Platform.Native.texture_create(width, height, format) do
          {:ok, texture_id} ->
            {[texture_id | avail],
             Map.put(map, texture_id, %{width: width, height: height, format: format})}

          {:error, reason} ->
            Logger.warning("Failed to create texture #{map_size(map) + 1}/#{count}: #{inspect(reason)}")
            {avail, map}
        end
      end)

    actual_count = length(available)

    if actual_count == 0 do
      Logger.error("Failed to create any textures in pool")
      {:stop, :texture_pool_empty}
    else
      Logger.info("Texture pool created: #{actual_count}/#{count} textures (#{width}x#{height})")

      {:ok, %__MODULE__{
        width: width,
        height: height,
        pool_size: actual_count,
        available: Enum.reverse(available),
        in_use: MapSet.new(),
        texture_map: texture_map,
      }}
    end
  end

  @impl GenServer
  def handle_call(:acquire, _from, %{available: []} = state) do
    Logger.warning("Texture pool exhausted (#{state.pool_size} textures in use)")
    {:reply, nil, state}
  end

  def handle_call(:acquire, _from, %{available: [id | rest]} = state) do
    in_use = MapSet.put(state.in_use, id)
    {:reply, id, %{state | available: rest, in_use: in_use}}
  end

  def handle_call(:stats, _from, state) do
    {:reply, %{
      available: length(state.available),
      in_use: MapSet.size(state.in_use),
      total: state.pool_size
    }, state}
  end

  @impl GenServer
  def handle_cast({:release, texture_id}, state) do
    if MapSet.member?(state.in_use, texture_id) do
      in_use = MapSet.delete(state.in_use, texture_id)
      {:noreply, %{state | available: [texture_id | state.available], in_use: in_use}}
    else
      {:noreply, state}
    end
  end

  @impl GenServer
  def terminate(_reason, state) do
    for {texture_id, _} <- state.texture_map do
      Dala.Platform.Native.texture_destroy(texture_id)
    end

    :ok
  end
end
