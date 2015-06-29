defmodule EZ.Transport.Supervisor do
  use Supervisor

  def start_link(callback) do
    Supervisor.start_link(__MODULE__,[Application.get_env(:ez, :interfaces), callback],[name: __MODULE__])
  end

  def init([interfaces, cb]) do
    import Supervisor.Spec, warn: false
    
    clients = interfaces |> Enum.map(fn (data) ->
      case data do
        {:tcp, ip_str, port} -> 
          {:ok, ip} = :inet_parse.address(ip_str)
          worker(EZ.Transport.TCP.Listener, [ip, port, cb, false], [id: "TCP.Listener.#{port}"])
        {:udp, ip_str, port} ->
          {:ok, ip} = :inet_parse.address(ip_str)
          worker(EZ.Transport.UDP.Listener, [ip, port, cb, false], [id: "UDP.Listener.#{port}"])
      end
    end)

    children = [
      supervisor(EZ.Transport.TCP.Supervisor, [[]]),
    ] ++ clients
    
    supervise(children, strategy: :one_for_one)
  end
end
