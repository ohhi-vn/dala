defmodule MlModelsApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :ml_models_app,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {MlModelsApp, []},
      extra_applications: [:logger, :phoenix_live_view]
    ]
  end

  defp deps do
    [
      {:dala, path: "../../"},
      {:nx, "~> 0.12"},
      {:axon, "~> 0.8"},
      {:jason, "~> 1.0"},
      {:req, "~> 0.5"},
      {:phoenix_live_view, "~> 1.1"}
    ]
  end
end
