use Mix.Config

config :ewebmachine,
  trace_dir: './traces'

config :ez,
  interfaces: [
    {:udp, '0.0.0.0', 6379},
    {:tcp, '0.0.0.0', 6379}
  ],
  rest_ip: '0.0.0.0',
  rest_port: 8082