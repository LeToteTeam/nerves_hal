defmodule Nerves.HAL.Mixfile do
  use Mix.Project

  @app :nerves_hal

  def project do
    [
      app: @app,
      version: "0.7.0",
      elixir: "~> 1.4",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      docs: [extras: ["README.md"], main: "readme"]
    ]
  end

  def application do
    [extra_applications: [:logger], mod: {Nerves.HAL.Application, []}]
  end

  defp deps do
    [
      {:system_registry, "~> 0.7"},
      {:gen_stage, "~> 0.13"},
      {:ex_doc, "~> 0.18", only: :dev},
      {:circuits_uart, "~> 1.3", optional: true}
    ]
  end

  defp description do
    "Hardware Abstraction Layer for Nerves Devices"
  end

  defp package do
    [
      maintainers: ["Justin Schneck"],
      licenses: ["Apache 2.0"],
      links: %{"Github" => "https://github.com/letoteteam/#{@app}"}
    ]
  end
end
