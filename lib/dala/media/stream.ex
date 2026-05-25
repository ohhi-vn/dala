defmodule Dala.Media.Stream do
  @moduledoc """
  Stream process supervisor.

  Manages the lifecycle of media stream processes:
  - VideoStreamActor — hardware-decoded video
  - AudioStreamActor — low-latency audio
  - RenderActor — GPU compositing
  - ClockActor — AV sync clock

  Each stream is an isolated BEAM process, matching the actor model.
  """

  use Supervisor

  @doc "Start the stream supervisor."
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Start a complete video stream with all actors."
  @spec start_video_stream(Dala.Socket.t(), String.t(), keyword()) ::
          {:ok, %{video: pid(), audio: pid() | nil, clock: pid(), scene: pid()}}
          | {:error, term()}
  def start_video_stream(socket, url, opts \\ []) do
    with {:ok, video} <- Dala.Media.Video.start_stream(socket, url, opts),
         {:ok, clock} <- Dala.Media.Clock.start_link(target_fps: Keyword.get(opts, :fps, 60)),
         width = Keyword.get(opts, :width, 1920),
         height = Keyword.get(opts, :height, 1080),
         {:ok, scene} <-
           Dala.Media.Scene.new(width, height, target_fps: Keyword.get(opts, :fps, 60)) do
      Dala.Media.Clock.subscribe(clock, scene)
      {:ok, %{video: video, audio: nil, clock: clock, scene: scene}}
    end
  end

  @doc "Start a camera stream with compositing."
  @spec start_camera_stream(Dala.Socket.t(), keyword()) ::
          {:ok, %{video: pid(), clock: pid(), scene: pid()}} | {:error, term()}
  def start_camera_stream(socket, opts \\ []) do
    with {:ok, video} <- Dala.Media.Video.start_camera_stream(socket, opts),
         {:ok, clock} <- Dala.Media.Clock.start_link(target_fps: 30),
         {:ok, scene} <- Dala.Media.Scene.new(1920, 1080, target_fps: 30) do
      Dala.Media.Clock.subscribe(clock, scene)
      {:ok, %{video: video, clock: clock, scene: scene}}
    end
  end

  @impl Supervisor
  def init(_opts) do
    children = []

    Supervisor.init(children, strategy: :one_for_one)
  end
end
