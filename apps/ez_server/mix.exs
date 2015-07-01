defmodule EZServer.Mixfile do
  use Mix.Project

  def project do
    [app: :ez_server,
     version: "0.0.1",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.0",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger, :ewebmachine],
     mod: {EZServer, []}]
  end

  defp deps do
    [{:ez_queue, in_umbrella: true},
     {:ewebmachine, github: "xirdev/ewebmachine"}]
  end
end
