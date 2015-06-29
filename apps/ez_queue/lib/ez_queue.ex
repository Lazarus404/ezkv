defmodule EZ.Queue do
  use Supervisor

  def start_link(callback) do
    Supervisor.start_link(__MODULE__,[],[name: __MODULE__])
  end

  def init([]) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(EZ.Queue.Supervisor, [[]]),
      worker(EZ.Queue.Manager, [])
    ]
    
    supervise(children, strategy: :one_for_one)
  end
end
