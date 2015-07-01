defmodule EZ.REST.Supervisor do
  use Supervisor
  def start_link, do: Supervisor.start_link(__MODULE__,[])
  def init([]) do
    supervise([
      supervisor(Ewebmachine.Sup,[[modules: [
                                              EZ.REST.Index
                                      ],
                                   ip: Application.get_env(:ez, :rest_ip, '0.0.0.0'),
                                   port: Application.get_env(:ez, :rest_port, 8080)]])
    ], strategy: :one_for_one)
  end
end
