defmodule Dala.Media.Adaptive do
  @moduledoc """
  Adaptive bitrate streaming and jitter buffer.

  Monitors network conditions and dynamically adjusts:
  - Video resolution and bitrate
  - Buffer size
  - Frame dropping strategy

  Borrowed from WebRTC / RTP / QUIC approaches.

  ## States

      :stable     → network is good, use highest quality
      :degrading  → packet loss detected, reduce quality
      :recovering → network improving, slowly ramp up
      :buffered   → buffer full, can increase quality

  ## Example

      {:ok, adapter} = Dala.Media.Adaptive.start_link(%{
        min_bitrate: 200_000,
        max_bitrate: 4_000_000,
        target_buffer_ms: 2000
      })

      # Report network stats (called by stream decoder)
      Dala.Media.Adaptive.report_stats(adapter, %{
        bytes_received: 50000,
        packets_lost: 2,
        jitter_ms: 15,
        rtt_ms: 80
      })
  """

  use GenServer

  require Logger

  @type adapter_ref :: pid()

  @default_min_bitrate 200_000
  @default_max_bitrate 4_000_000
  @default_target_buffer_ms 2000
  @default_min_buffer_ms 500

  defstruct [
    :state,              # :stable | :degrading | :recovering | :buffered
    :current_bitrate,
    :min_bitrate,
    :max_bitrate,
    :target_buffer_ms,
    :min_buffer_ms,
    :current_buffer_ms,
    :stats_history,      # list of recent network stats
    :last_adjustment_ms, # timestamp of last quality adjustment
    :adjustment_interval_ms,
  ]

  # Client API

  @doc "Start the adaptive bitrate adapter."
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc "Report network statistics from the stream decoder."
  @spec report_stats(adapter_ref(), map()) :: :ok
  def report_stats(pid, stats) do
    GenServer.cast(pid, {:report_stats, stats})
  end

  @doc "Get the current recommended bitrate."
  @spec recommended_bitrate(adapter_ref()) :: non_neg_integer()
  def recommended_bitrate(pid) do
    GenServer.call(pid, :get_bitrate)
  end

  @doc "Get the current recommended resolution."
  @spec recommended_resolution(adapter_ref()) :: {non_neg_integer(), non_neg_integer()}
  def recommended_resolution(pid) do
    GenServer.call(pid, :get_resolution)
  end

  @doc "Get current adapter state."
  @spec get_state(adapter_ref()) :: atom()
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  @doc "Get full diagnostic info."
  @spec diagnostic(adapter_ref()) :: map()
  def diagnostic(pid) do
    GenServer.call(pid, :diagnostic)
  end

  # Server callbacks

  @impl GenServer
  def init(opts) do
    min_bitrate = Keyword.get(opts, :min_bitrate, @default_min_bitrate)
    max_bitrate = Keyword.get(opts, :max_bitrate, @default_max_bitrate)

    {:ok, %__MODULE__{
      state: :stable,
      current_bitrate: max_bitrate,
      min_bitrate: min_bitrate,
      max_bitrate: max_bitrate,
      target_buffer_ms: Keyword.get(opts, :target_buffer_ms, @default_target_buffer_ms),
      min_buffer_ms: Keyword.get(opts, :min_buffer_ms, @default_min_buffer_ms),
      current_buffer_ms: 0,
      stats_history: [],
      last_adjustment_ms: 0,
      adjustment_interval_ms: Keyword.get(opts, :adjustment_interval_ms, 1000),
    }}
  end

  @impl GenServer
  def handle_cast({:report_stats, stats}, state) do
    history = Enum.take([stats | state.stats_history], 10)
    now = System.monotonic_time(:millisecond)

    state =
      if now - state.last_adjustment_ms >= state.adjustment_interval_ms do
        evaluate(%{state | history: history, last_adjustment_ms: now})
      else
        %{state | history: history}
      end

    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:get_bitrate, _from, state) do
    {:reply, state.current_bitrate, state}
  end

  def handle_call(:get_resolution, _from, state) do
    {:reply, bitrate_to_resolution(state.current_bitrate), state}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state.state, state}
  end

  def handle_call(:diagnostic, _from, state) do
    {:reply, %{
      state: state.state,
      current_bitrate: state.current_bitrate,
      min_bitrate: state.min_bitrate,
      max_bitrate: state.max_bitrate,
      current_buffer_ms: state.current_buffer_ms,
      target_buffer_ms: state.target_buffer_ms,
      resolution: bitrate_to_resolution(state.current_bitrate),
      samples: length(state.stats_history),
    }, state}
  end

  # Private — adaptive algorithm

  defp evaluate(%{history: []} = state), do: state

  defp evaluate(state) do
    avg_jitter = average(state.stats_history, :jitter_ms)
    avg_rtt = average(state.stats_history, :rtt_ms)
    loss_rate = loss_rate(state.stats_history)

    cond do
      # High packet loss or high jitter → degrade
      loss_rate > 0.05 or avg_jitter > 50 ->
        degrade(state)

      # Buffer running low → increase buffer, reduce quality
      state.current_buffer_ms < state.min_buffer_ms ->
        %{state | state: :degrading}
        |> reduce_bitrate()

      # Network is good and buffer is healthy → try to improve
      loss_rate < 0.01 and avg_rtt < 100 and state.current_buffer_ms > state.target_buffer_ms ->
        recover(state)

      # Stable
      true ->
        %{state | state: :stable}
    end
  end

  defp degrade(state) do
    %{state | state: :degrading}
    |> reduce_bitrate()
  end

  defp recover(state) do
    new_bitrate = min(state.max_bitrate, round(state.current_bitrate * 1.1))
    %{state | state: :recovering, current_bitrate: new_bitrate}
  end

  defp reduce_bitrate(state) do
    new_bitrate = max(state.min_bitrate, round(state.current_bitrate * 0.7))
    %{state | current_bitrate: new_bitrate}
  end

  defp average(samples, key) do
    values = Enum.map(samples, &Map.get(&1, key, 0))
    if length(values) > 0, do: Enum.sum(values) / length(values), else: 0
  end

  defp loss_rate(samples) do
    total_packets = Enum.reduce(samples, 0, &(&1[:packets_received] || 0) + &2)
    total_lost = Enum.reduce(samples, 0, &(&1[:packets_lost] || 0) + &2)

    if total_packets > 0 do
      total_lost / (total_packets + total_lost)
    else
      0.0
    end
  end

  defp bitrate_to_resolution(bitrate) when bitrate >= 4_000_000, do: {1920, 1080}
  defp bitrate_to_resolution(bitrate) when bitrate >= 2_000_000, do: {1280, 720}
  defp bitrate_to_resolution(bitrate) when bitrate >= 1_000_000, do: {854, 480}
  defp bitrate_to_resolution(bitrate) when bitrate >= 500_000, do: {640, 360}
  defp bitrate_to_resolution(_), do: {480, 270}
end
