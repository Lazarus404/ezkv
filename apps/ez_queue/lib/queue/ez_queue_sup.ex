defmodule EZ.Queue.Supervisor do
  use Supervisor
  require Logger

  def start_link(_args) do
    :supervisor.start_link({:local, __MODULE__}, __MODULE__, [])
  end

  def start_child() do
    :supervisor.start_child(__MODULE__, [])
  end
 
  def terminate_child(child) do
    :supervisor.terminate_child(__MODULE__, child)
  end

  def init([]) do
    tree = [ worker(EZ.Queue.Client, [], restart: :temporary) ]
    supervise(tree, strategy: :simple_one_for_one)
  end
end