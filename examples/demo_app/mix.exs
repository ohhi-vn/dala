defmodule DemoApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :demo_app,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {DemoApp, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:dala, path: "../../"}
    ]
  end
end
