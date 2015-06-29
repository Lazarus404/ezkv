defmodule EZServer do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(EZ.Transport.Supervisor, [[]]),
      supervisor(EZ.Queue, [[]])
    ]

    opts = [strategy: :one_for_one, name: EZServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
