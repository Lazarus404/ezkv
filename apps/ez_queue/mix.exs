defmodule EZ.Queue.Mixfile do
  use Mix.Project

  def project do
    [app: :ez_queue,
     version: "0.0.1",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [{:ez_proto, in_umbrella: true}]
  end
end
