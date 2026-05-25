defmodule Dala.Media.Video do
  @moduledoc """
  Hardware-accelerated video streaming surface.

  Uses VideoToolbox (iOS) / MediaCodec (Android) for zero-copy GPU texture rendering.
  Decoded frames become GPU textures directly — no CPU bitmap copy.

  Architecture:
      H264/H265 stream → Hardware Decoder → GPU Texture → Renderer

  ## Example

      # Start a video stream from URL
      {:ok, stream} = Dala.Media.Video.start_stream(socket, "https://example.com/video.mp4")

      # Control playback
      Dala.Media.Video.play(stream)
      Dala.Media.Video.pause(stream)
      Dala.Media.Video.seek(stream, 5000)  # milliseconds

      # Events arrive as handle_info:
      #   {:video, :frame_ready, %{texture_id: id, pts: timestamp}}
      #   {:video, :ended, %{}}
      #   {:video, :error, %{reason: reason}}
  """

  use GenServer

  require Logger

  @type stream_ref :: pid()
  @type timestamp_ms :: non_neg_integer()
  @type texture_id :: non_neg_integer()

  defstruct [
    :socket,
    :url,
    :width,
    :height,
    :state,
    :duration_ms,
    :position_ms,
    :volume,
    :loop,
    :texture_id,
    :decoder_ref
  ]

  # Client API

  @doc "Start a video stream from a URL or local path."
  @spec start_stream(Dala.Socket.t(), String.t(), keyword()) ::
          {:ok, stream_ref()} | {:error, term()}
  def start_stream(socket, url, opts \\ []) do
    GenServer.start_link(__MODULE__, {socket, url, opts})
  end

  @doc "Start a stream from a camera feed (uses existing camera preview)."
  @spec start_camera_stream(Dala.Socket.t(), keyword()) :: {:ok, stream_ref()} | {:error, term()}
  def start_camera_stream(socket, opts \\ []) do
    GenServer.start_link(__MODULE__, {socket, :camera, opts})
  end

  @doc "Start decoding a stream but don't render yet (for buffering)."
  @spec prepare_stream(Dala.Socket.t(), String.t(), keyword()) ::
          {:ok, stream_ref()} | {:error, term()}
  def prepare_stream(socket, url, opts \\ []) do
    GenServer.start_link(__MODULE__, {socket, url, Keyword.put(opts, :prepare_only, true)})
  end

  @doc "Resume or start playback."
  @spec play(stream_ref()) :: :ok
  def play(pid), do: GenServer.cast(pid, :play)

  @doc "Pause playback (keeps decoder and texture alive)."
  @spec pause(stream_ref()) :: :ok
  def pause(pid), do: GenServer.cast(pid, :pause)

  @doc "Seek to a position in milliseconds."
  @spec seek(stream_ref(), timestamp_ms()) :: :ok
  def seek(pid, position_ms), do: GenServer.cast(pid, {:seek, position_ms})

  @doc "Stop playback and release all resources."
  @spec stop(stream_ref()) :: :ok
  def stop(pid), do: GenServer.stop(pid)

  @doc "Set volume (0.0 to 1.0)."
  @spec set_volume(stream_ref(), float()) :: :ok
  def set_volume(pid, volume), do: GenServer.cast(pid, {:set_volume, volume})

  @doc "Set whether the stream should loop."
  @spec set_loop(stream_ref(), boolean()) :: :ok
  def set_loop(pid, loop?), do: GenServer.cast(pid, {:set_loop, loop?})

  @doc "Get current playback position in milliseconds."
  @spec position(stream_ref()) :: timestamp_ms()
  def position(pid), do: GenServer.call(pid, :get_position)

  @doc "Get stream duration in milliseconds."
  @spec duration(stream_ref()) :: timestamp_ms() | :unknown
  def duration(pid), do: GenServer.call(pid, :get_duration)

  @doc "Get current state."
  @spec state(stream_ref()) :: atom()
  def state(pid), do: GenServer.call(pid, :get_state)

  @doc "Get the GPU texture ID for the current frame (for compositing)."
  @spec current_texture(stream_ref()) :: texture_id() | nil
  def current_texture(pid), do: GenServer.call(pid, :get_texture)

  # Server callbacks

  @impl GenServer
  def init({socket, source, opts}) do
    state = %__MODULE__{
      socket: socket,
      url: if(source == :camera, do: nil, else: source),
      width: Keyword.get(opts, :width, 0),
      height: Keyword.get(opts, :height, 0),
      state: :idle,
      duration_ms: 0,
      position_ms: 0,
      volume: Keyword.get(opts, :volume, 1.0),
      loop: Keyword.get(opts, :loop, false),
      texture_id: nil,
      decoder_ref: nil
    }

    state =
      if source == :camera do
        facing = Keyword.get(opts, :facing, :back) |> Atom.to_string()
        Dala.Platform.Native.camera_start_preview(Jason.encode!(%{"facing" => facing}))
        %{state | decoder_ref: :camera}
      else
        # URL stream: initialize hardware decoder via native
        case Dala.Platform.Native.video_init_decoder(source) do
          {:ok, ref} ->
            %{state | decoder_ref: ref}

          {:error, reason} ->
            Logger.error("Failed to init video decoder: #{inspect(reason)}")
            %{state | state: :error}
        end
      end

    {:ok, state}
  end

  @impl GenServer
  def handle_cast(:play, %__MODULE__{state: :playing} = state), do: {:noreply, state}

  def handle_cast(:play, state) do
    notify(state.socket, :video, :playing, %{})
    {:noreply, %{state | state: :playing}}
  end

  def handle_cast(:pause, state) do
    notify(state.socket, :video, :paused, %{position: state.position_ms})
    {:noreply, %{state | state: :paused}}
  end

  def handle_cast({:seek, position_ms}, state) do
    notify(state.socket, :video, :seeking, %{position: position_ms})
    {:noreply, %{state | state: :seeking, position_ms: position_ms}}
  end

  def handle_cast({:set_volume, volume}, state) do
    {:noreply, %{state | volume: max(0.0, min(1.0, volume))}}
  end

  def handle_cast({:set_loop, loop?}, state) do
    {:noreply, %{state | loop: loop?}}
  end

  @impl GenServer
  def handle_call(:get_position, _from, state), do: {:reply, state.position_ms, state}
  def handle_call(:get_duration, _from, state), do: {:reply, state.duration_ms, state}
  def handle_call(:get_state, _from, state), do: {:reply, state.state, state}
  def handle_call(:get_texture, _from, state), do: {:reply, state.texture_id, state}

  @impl GenServer
  def terminate(_reason, %__MODULE__{decoder_ref: :camera}) do
    Dala.Platform.Native.camera_stop_preview()
    :ok
  end

  def terminate(_reason, %__MODULE__{decoder_ref: ref}) when is_reference(ref) do
    Dala.Platform.Native.video_release_decoder(ref)
    :ok
  end

  def terminate(_reason, _), do: :ok

  # Private

  defp notify(socket, :video, event, data) do
    send(socket.__dala__.screen, {:video, event, data})
  end
end
