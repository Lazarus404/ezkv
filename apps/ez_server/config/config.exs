use Mix.Config

config :ez,
  interfaces: [
    {:udp, '0.0.0.0', 6379},
    {:tcp, '0.0.0.0', 6379}
  ]