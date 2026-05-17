defmodule Dala.Ui.GpuCanvas do
  @moduledoc """
  A GPU-accelerated canvas component for Dala UI trees.

  Use this when you need custom pixel-level rendering inside a Dala screen.

  ## Props

  - `:width` — Canvas width in pixels (default: 256)
  - `:height` — Canvas height in pixels (default: 256)
  - `:paint` — A `fun/2` that receives the surface pid and info map, required

  ## Example

      defmodule MyApp.CanvasScreen do
        use Dala.Screen

        def render(assigns) do
          ~H\"\"\"
          <GpuCanvas width={256} height={256} paint={&paint/2} />
          \"\"\"
        end

        def paint(canvas, _info) do
          Dala.Gpu.clear(canvas, :black)
          Dala.Gpu.fill_rect(canvas, 10, 10, 100, 100, :red)
          Dala.Gpu.present(canvas)
        end
      end
  """

  # TODO: Dala.Ui.Widgets is a function collection, not a behaviour.
  # This component needs a proper behaviour module to use.
  # use Dala.Ui.Widgets

  @doc false
  def props do
    [
      width: [type: :integer, default: 256],
      height: [type: :integer, default: 256],
      paint: [type: :fun, required: true]
    ]
  end
end
