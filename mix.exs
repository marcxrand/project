defmodule Project.MixProject do
  use Mix.Project

  def project do
    [
      app: :project,
      version: "1.0.12",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      docs: [
        main: "readme",
        extras: ["README.md", "CHANGELOG.md"]
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:igniter, "~> 0.6"},
      {:ex_doc, "~> 0.30", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      description: "Composable Igniter tasks for bootstrapping Phoenix applications",
      maintainers: ["marcxrand"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/marcxrand/project"},
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* CHANGELOG*)
    ]
  end
end
