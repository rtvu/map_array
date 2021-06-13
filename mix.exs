defmodule MapArray.MixProject do
  use Mix.Project

  def project do
    [
      app: :map_array,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      name: "MapArray",
      source_url: "https://github.com/rtvu/map_array",
      docs: [
        main: "MapArray"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.24", only: :dev, runtime: false}
    ]
  end
end
