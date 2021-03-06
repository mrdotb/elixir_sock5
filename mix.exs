defmodule ElixirSocks5.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_socks5,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :ranch]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ranch, "~> 1.7"}
    ]
  end
end
