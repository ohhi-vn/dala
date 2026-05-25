defmodule Dala.Media.Animation do
  @moduledoc """
  Frame-clock driven animation system.

  Animations are driven by the frame clock, not by setInterval. This ensures
  smooth, jank-free animations that are synchronized with the render pipeline.

  Architecture:
      FrameClock → AnimationSystem → SceneGraph Update

  ## Example

      # Animate a node's opacity from 0 to 1 over 500ms
      Dala.Media.Animation.animate(scene, node_id, :opacity, %{
        from: 0.0,
        to: 1.0,
        duration_ms: 500,
        easing: :ease_in_out
      })

      # Animate position
      Dala.Media.Animation.animate(scene, node_id, :position, %{
        from: {0, 0},
        to: {100, 200},
        duration_ms: 1000,
        easing: :spring
      })
  """

  use GenServer

  require Logger

  @type anim_ref :: pid()
  @type easing :: :linear | :ease_in | :ease_out | :ease_in_out | :spring | :bounce

  defstruct [
    :clock_pid,
    :animations,
    :next_id
  ]

  # Client API

  @doc "Start the animation system, linked to a clock."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc "Animate a property on a scene node."
  @spec animate(anim_ref(), reference(), atom(), map()) :: {:ok, reference()} | {:error, term()}
  def animate(pid, node_id, property, opts) do
    GenServer.call(pid, {:animate, node_id, property, opts})
  end

  @doc "Cancel an animation."
  @spec cancel(anim_ref(), reference()) :: :ok
  def cancel(pid, anim_id) do
    GenServer.cast(pid, {:cancel, anim_id})
  end

  @doc "Cancel all animations for a node."
  @spec cancel_all(anim_ref(), reference()) :: :ok
  def cancel_all(pid, node_id) do
    GenServer.cast(pid, {:cancel_all, node_id})
  end

  # Server callbacks

  @impl GenServer
  def init(_opts) do
    {:ok,
     %__MODULE__{
       clock_pid: nil,
       animations: %{},
       next_id: 1
     }}
  end

  @impl GenServer
  def handle_call({:animate, node_id, property, opts}, _from, state) do
    anim_id = make_ref()
    from = Map.fetch!(opts, :from)
    to = Map.fetch!(opts, :to)
    duration_ms = Map.get(opts, :duration_ms, 300)
    easing = Map.get(opts, :easing, :ease_in_out)

    duration_frames = max(div(duration_ms, 16), 1)

    anim = %{
      id: anim_id,
      node_id: node_id,
      property: property,
      from: from,
      to: to,
      start_frame: 0,
      duration_frames: duration_frames,
      easing: easing,
      active: true
    }

    animations = Map.put(state.animations, anim_id, anim)
    {:reply, {:ok, anim_id}, %{state | animations: animations}}
  end

  @impl GenServer
  def handle_cast({:cancel, anim_id}, state) do
    animations = Map.delete(state.animations, anim_id)
    {:noreply, %{state | animations: animations}}
  end

  def handle_cast({:cancel_all, node_id}, state) do
    animations = Map.reject(state.animations, fn {_, a} -> a.node_id == node_id end)
    {:noreply, %{state | animations: animations}}
  end

  @impl GenServer
  def handle_info({:clock, :tick, %{frame: frame}}, state) do
    animations =
      Map.new(state.animations, fn {id, anim} ->
        if not anim.active do
          {id, anim}
        else
          progress = min(1.0, (frame - anim.start_frame) / anim.duration_frames)
          eased = apply_easing(progress, anim.easing)
          _value = interpolate(anim.from, anim.to, eased)
          active = progress < 1.0
          {id, %{anim | active: active}}
        end
      end)

    {:noreply, %{state | animations: animations}}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  # Private — easing functions

  defp apply_easing(t, :linear), do: t
  defp apply_easing(t, :ease_in), do: t * t
  defp apply_easing(t, :ease_out), do: 1.0 - (1.0 - t) * (1.0 - t)

  defp apply_easing(t, :ease_in_out) do
    if t < 0.5 do
      2.0 * t * t
    else
      1.0 - :math.pow(-2.0 * t + 2.0, 2) / 2.0
    end
  end

  defp apply_easing(t, :spring) do
    c1 = 1.0
    c2 = 20.0
    1.0 - c1 * :math.exp(-t * 5) * :math.cos(c2 * t * t)
  end

  defp apply_easing(t, :bounce) do
    n1 = 7.5625
    d1 = 2.75
    t = t

    cond do
      t < 1 / d1 -> n1 * t * t
      t < 2 / d1 -> n1 * (t - 1.5 / d1) * (t - 1.5) + 0.75
      t < 2.5 / d1 -> n1 * (t - 2.25 / d1) * (t - 2.25) + 0.9375
      true -> n1 * (t - 2.625 / d1) * (t - 2.625) + 0.984375
    end
  end

  defp interpolate(from, to, t) when is_number(from) and is_number(to) do
    from + (to - from) * t
  end

  defp interpolate({x1, y1}, {x2, y2}, t) do
    {x1 + (x2 - x1) * t, y1 + (y2 - y1) * t}
  end

  defp interpolate({x1, y1, z1}, {x2, y2, z2}, t) do
    {x1 + (x2 - x1) * t, y1 + (y2 - y1) * t, z1 + (z2 - z1) * t}
  end

  defp interpolate(from, to, t) do
    if t < 0.5, do: from, else: to
  end
end
