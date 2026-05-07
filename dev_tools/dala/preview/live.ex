defmodule Dala.Preview.Live do
  @moduledoc """
  Standalone Phoenix LiveView server for Dala Preview Designer.

  Starts a complete Phoenix endpoint serving the interactive drag-and-drop
  design canvas at `http://localhost:<port>/`. The canvas lets you:
  - Drag components from a palette onto a design canvas
  - Edit component properties in a sidebar
  - See a live phone-frame preview
  - Generate screen module code in sigil or DSL style

  ## Usage

      # Start with default settings
      Dala.Preview.Live.start_server()

      # Start with a specific port
      Dala.Preview.Live.start_server(port: 4200)

      # Start with an initial UI tree
      Dala.Preview.Live.start_server(ui_tree: my_tree, port: 4000)
  """

  @doc """
  Start the standalone LiveView server.

  Options:
    - `:port` - Port to run on (default: 4200)
    - `:ui_tree` - Initial UI tree map (default: empty column)
    - `:module_name` - Default module name (default: "MyApp.HomeScreen")
    - `:open` - Open browser after start (default: true)
  """
  def start_server(opts \\ []) do
    port = Keyword.get(opts, :port, 4200)
    ui_tree = Keyword.get(opts, :ui_tree)
    module_name = Keyword.get(opts, :module_name, "MyApp.HomeScreen")
    open? = Keyword.get(opts, :open, true)

    :persistent_term.put({__MODULE__, :initial_tree}, ui_tree)
    :persistent_term.put({__MODULE__, :initial_module}, module_name)

    ensure_supervisor()
    ensure_pubsub()
    ensure_endpoint(port)

    url = "http://localhost:#{port}/"

    IO.puts("""

    ┌─────────────────────────────────────────────────┐
    │  Dala Preview Designer                          │
    │  #{url}                    │
    │                                                 │
    │  Drag components from the palette to design     │
    │  your screen. Switch between Sigil and DSL      │
    │  style code generation.                         │
    │                                                 │
    │  Press Ctrl+C twice to stop.                    │
    └─────────────────────────────────────────────────┘
    """)

    if open?, do: open_browser(url)

    {:ok, url}
  rescue
    e ->
      IO.puts("Failed to start Dala Preview Designer: #{inspect(e)}")
      {:error, e}
  end

  @doc """
  Stop the LiveView server.
  """
  def stop_server do
    endpoint = endpoint_module()

    if Code.ensure_loaded?(endpoint) do
      Supervisor.stop(endpoint)
    end
  end

  defp endpoint_module, do: Module.concat(__MODULE__, Endpoint)

  defp ensure_supervisor do
    case Process.whereis(Dala.Preview.Supervisor) do
      nil ->
        {:ok, _} =
          Supervisor.start_link([], name: Dala.Preview.Supervisor, strategy: :one_for_one)

      _ ->
        :ok
    end
  end

  defp ensure_pubsub do
    case Process.whereis(Dala.Preview.PubSub) do
      nil ->
        Supervisor.start_child(
          Dala.Preview.Supervisor,
          {Phoenix.PubSub, name: Dala.Preview.PubSub}
        )

      _ ->
        :ok
    end
  end

  defp ensure_endpoint(port) do
    endpoint = endpoint_module()

    config = [
      http: [port: port],
      server: true,
      secret_key_base: String.duplicate("dala_preview_dev_secret_key_base_for_local_use_only", 4),
      live_view: [signing_salt: "dala_preview_signing_salt"],
      pubsub_server: Dala.Preview.PubSub,
      debug_errors: true
    ]

    Application.put_env(:dala, endpoint, config)

    unless Code.ensure_loaded?(endpoint) do
      define_endpoint(endpoint)
    end

    case Process.whereis(endpoint) do
      nil ->
        Supervisor.start_child(Dala.Preview.Supervisor, {endpoint, []})

      _ ->
        :ok
    end
  end

  defp define_endpoint(module) do
    Module.create(
      module,
      quote do
        use Phoenix.Endpoint, otp_app: :dala

        socket("/live", Phoenix.LiveView.Socket)

        plug(Plug.Parsers,
          parsers: [:urlencoded, :multipart, :json],
          pass: ["*/*"],
          json_decoder: Phoenix.json_library()
        )

        plug(Plug.Session,
          store: :cookie,
          key: "_dala_preview",
          signing_salt: "dala_preview_dev"
        )

        plug(:fetch_session)

        plug(:router)

        def router(conn, _) do
          case conn.method do
            "GET" ->
              conn
              |> Phoenix.LiveView.Controller.live_render(Dala.Preview.Canvas,
                session: %{
                  "initial_tree" => :persistent_term.get({Dala.Preview.Live, :initial_tree}, nil),
                  "initial_module" =>
                    :persistent_term.get(
                      {Dala.Preview.Live, :initial_module},
                      "MyApp.HomeScreen"
                    )
                }
              )

            _ ->
              Plug.Conn.send_resp(conn, 405, "Method Not Allowed")
          end
        end
      end,
      file: "dala_preview_endpoint"
    )

    Code.compile_quoted(module)
  end

  defp open_browser(url) do
    System.cmd("open", [url], stderr_to_stdout: true)
  rescue
    _ -> :ok
  end
end
