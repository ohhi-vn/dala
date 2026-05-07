defmodule Mix.Tasks.Dala.Preview do
  @moduledoc """
  Preview Dala UI designs in a browser without a simulator/emulator.

  Two modes:

  1. **Static preview** — generates an HTML file and opens it in the browser.
     No server needed. Good for quick visual checks.

  2. **Live designer** — starts a Phoenix LiveView server with an interactive
     drag-and-drop component palette, property editor, live phone-frame preview,
     and code generation (sigil or DSL style).

  ## Usage

      # Static preview of a screen module
      mix dala.preview MyApp.HomeScreen

      # Static preview with custom output file
      mix dala.preview MyApp.HomeScreen --output preview.html

      # Don't open in browser (just generate the file)
      mix dala.preview MyApp.HomeScreen --no-open

      # Hide the component tree in the preview
      mix dala.preview MyApp.HomeScreen --no-tree

      # Start the live designer
      mix dala.preview --live

      # Live designer with custom port and module name
      mix dala.preview --live --port 4200 --module MyApp.SettingsScreen

  ## Options

    * `--live` / `-l` - Start the live designer server (drag-and-drop UI builder)
    * `--output` / `-o` - Output file path for static preview (default: dala_preview.html)
    * `--no-open` - Don't open in browser after generating
    * `--no-tree` - Don't show the component tree in the preview
    * `--title` - Custom title for the preview page
    * `--port` - Port for the live designer (default: 4200)
    * `--module` - Module name for code generation (default: MyApp.HomeScreen)

  ## Examples

      mix dala.preview MyApp.CounterScreen
      mix dala.preview MyApp.LoginScreen --output login_preview.html
      mix dala.preview MyApp.HomeScreen --title "Home Screen Preview" --no-open
      mix dala.preview --live
      mix dala.preview --live --port 4000 --module MyApp.SettingsScreen
  """

  use Mix.Task

  @shortdoc "Preview Dala UI designs in browser"

  @impl Mix.Task
  def run(args) do
    {opts, rest, _} =
      OptionParser.parse(args,
        switches: [
          output: :string,
          open: :boolean,
          tree: :boolean,
          title: :string,
          live: :boolean,
          port: :integer,
          module: :string
        ],
        aliases: [o: :output, l: :live]
      )

    if Keyword.get(opts, :live, false) do
      run_live_designer(opts)
    else
      run_static_preview(opts, rest)
    end
  end

  defp run_live_designer(opts) do
    port = Keyword.get(opts, :port, 4200)
    module_name = Keyword.get(opts, :module, "MyApp.HomeScreen")

    Mix.shell().info("Starting Dala Preview Designer on http://localhost:#{port}/")

    Dala.Preview.start_designer(
      port: port,
      module_name: module_name,
      open: Keyword.get(opts, :open, true)
    )
  end

  defp run_static_preview(opts, rest) do
    output = Keyword.get(opts, :output, "dala_preview.html")
    open? = Keyword.get(opts, :open, true)
    show_tree? = Keyword.get(opts, :tree, true)
    title = Keyword.get(opts, :title)

    case rest do
      [] ->
        Mix.shell().error("Please provide a module name to preview.")
        Mix.shell().info("Usage: mix dala.preview ModuleName [options]")
        Mix.shell().info("       mix dala.preview --live [options]")
        exit({:shutdown, 1})

      [module_name | _] ->
        module = Module.concat([module_name])

        unless Code.ensure_loaded?(module) do
          Mix.shell().error("Module #{module_name} not found or not compiled.")
          Mix.shell().info("Make sure the module is defined and the code is compiled.")
          exit({:shutdown, 1})
        end

        preview_opts = []
        preview_opts = if show_tree?, do: preview_opts, else: [{:show_tree, false} | preview_opts]
        preview_opts = if title, do: [{:title, title} | preview_opts], else: preview_opts

        Mix.shell().info("Generating preview for #{module_name}...")

        path = Dala.Preview.preview_to_file(module, output, preview_opts)

        if open? do
          Mix.shell().info("Opening preview in browser...")
          Dala.Preview.open_in_browser(path)
        else
          Mix.shell().info("Preview saved to: #{path}")
          Mix.shell().info("Open this file in your browser to view the preview.")
        end
    end
  end
end
