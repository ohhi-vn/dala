defmodule Dala.Theme.Adaptive do
  @moduledoc """
  Theme that follows the OS-level light / dark setting.

  At call time `theme/0` reads `Dala.Theme.Theme.color_scheme/0` and returns
  `Dala.Theme.Light.theme/0` or `Dala.Theme.Dark.theme/0`. Built for
  outdoor working users — sun-readable in daytime, eye-friendly at night.

  ## Usage

      defmodule MyApp do
        use Dala.App, theme: Dala.Theme.Adaptive
      end

  ## Reactive switching

  `Dala.Theme.set/1` snapshots the theme at call time, so toggling the OS
  appearance after the app has started does not auto-update the rendered
  theme. To re-evaluate, call `Dala.Theme.set(Dala.Theme.Adaptive)` again
  (e.g. in response to a foreground / lifecycle event, or after a planned
  `:color_scheme_changed` device event in a future version).
  """

  @doc "Returns the Light or Dark theme struct based on the current OS appearance."
  @spec theme() :: Dala.Theme.t()
  def theme do
    case Dala.Theme.Theme.color_scheme() do
      :dark -> Dala.Theme.Dark.theme()
      _ -> Dala.Theme.Light.theme()
    end
  end

  defmodule Custom do
    @moduledoc """
    Adaptive theme that switches between a custom dark/light pair.

        defmodule MyApp do
          use Dala.App, theme: Dala.Theme.Adaptive.new(
            dark: Dala.Theme.Obsidian,
            light: Dala.Theme.Light
          )
        end
    """
    defstruct [:dark, :light]

    @doc "Create a new adaptive theme with a dark/light pair."
    @spec new(keyword()) :: %__MODULE__{}
    def new(opts) do
      %__MODULE__{
        dark: Keyword.get(opts, :dark, Dala.Theme.Dark),
        light: Keyword.get(opts, :light, Dala.Theme.Light)
      }
    end

    @doc "Returns the appropriate theme based on current OS appearance."
    @spec theme(%__MODULE__{}) :: Dala.Theme.t()
    def theme(%__MODULE__{dark: dark, light: light}) do
      case Dala.Theme.Theme.color_scheme() do
        :dark -> dark.theme()
        _ -> light.theme()
      end
    end
  end
end
