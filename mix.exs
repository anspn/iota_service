defmodule IotaService.MixProject do
  use Mix.Project

  def project do
    [
      app: :iota_service,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),

      # Docs
      name: "IotaService",
      source_url: "https://github.com/yourusername/iota_service",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {IotaService.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # IOTA NIF library (fetched via git)
      {:iota_nif, git: "https://github.com/anspn/iota_nif.git", branch: "main"},

      # JSON parsing
      {:jason, "~> 1.4"},

      # HTTP client
      {:req, "~> 0.5"},

      # Telemetry for metrics
      {:telemetry, "~> 1.2"},

      # Development/Test dependencies
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md"]
    ]
  end
end
