defmodule Snooper.MixProject do
  use Mix.Project

  def project do
    [
      app: :snooper,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      source_url: "https://github.com/ericentin/snooper"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    "Easily debug, inspect, and log a function's behavior on a line-by-line basis."
  end

  defp deps do
    [{:ex_doc, "~> 0.19", only: :dev, runtime: false}]
  end

  defp package do
    [
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE src),
      licenses: ["Apache 2.0"],
      links: %{"GitHub" => "https://github.com/ericentin/snooper"}
    ]
  end
end
