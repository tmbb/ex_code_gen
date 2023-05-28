defmodule CodeGen.MixProject do
  use Mix.Project

  def project do
    [
      app: :code_gen,
      version: "0.2.1",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "Flexible code generation for Elixir projects",
      package: package()
    ]
  end

  defp package() do
    [
      # This option is only needed when you don't want to use the OTP application name
      name: "code_gen",
      # These are the default files included in the package
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/tmbb/ex_code_gen"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/fixtures/immutable"]
  defp elixirc_paths(:dev), do: ["lib", "test/fixtures/immutable"]
  defp elixirc_paths(_other), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.29", only: :dev},
      {:makeup_eex, "~> 0.1.0", only: :dev}
    ]
  end
end
