defmodule EZ.Transport.TCP.Client do
  @moduledoc """
  TCP protocol socket client for STUN connections
  """
  use GenServer
  alias EZ.Queue.Manager, as: Queue
  require Logger
  @vsn "0"

  #####
  # External API

  @doc """
  Standard OTP module startup
  """
  def start_link(socket, callback, ssl) do
    GenServer.start_link(__MODULE__, [socket, callback, ssl])
  end

  def create(socket, callback, ssl) do
    EZ.Transport.TCP.Supervisor.start_child(socket, callback, ssl)
  end

  def send_to_client(pid, msg) do
    GenServer.cast(pid, {:message, msg})
  end

  def init([socket, callback, ssl]) do
    Logger.debug "Client init"
    {:ok, %{:callback => callback, :accepted => false, :list_socket => socket, :cli_socket => nil, :addr => nil, :msg_buffer => <<>>, :ssl => ssl, :bucket => "0"}, 0}
  end

  @doc """
  Asynchronous socket response handler  
  """
  def handle_cast({:message, msg}, %{:cli_socket => socket} = state) do
    # Select proper client
    Logger.debug "Dispatching TCP to client | #{inspect byte_size(msg)} bytes"
    send_msg(socket, msg)
    {:noreply, state}
  end

  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end

  def handle_cast(other, state) do
    Logger.debug "TCP client: strange cast: #{inspect other}"
    {:noreply, state}
  end

  def handle_call(other, _from, state) do
    Logger.debug "TCP client: strange call: #{inspect other}"
    {:noreply, state}
  end

  def handle_info(:timeout, %{:list_socket => list_socket = {:sslsocket, _,_}, :callback => cb} = state) do
    Logger.debug "TCP call on handle_info"
    {:ok, cli_socket} = :ssl.transport_accept(list_socket)
    case :ssl.ssl_accept(cli_socket) do
      :ok ->
        Logger.debug "Client ssl accept"
        create(list_socket, cb, state.ssl)
        case set_sockopt(list_socket, cli_socket) do
          :ok -> :ok
          {:error, reason} -> exit({:set_sockopt, reason})
        end
        :ssl.setopts(cli_socket, [{:active, :once}, :binary])
        {:ok, client_ip_port} = :ssl.peername(cli_socket)
        {:ok, server_ip_port} = :ssl.sockname(cli_socket)
        {:noreply, %{state | :accepted => true, :cli_socket => cli_socket, :addr => {client_ip_port, server_ip_port}}}
      {:error, reason} ->
        Logger.debug "Client ssl accept error"
        :erlang.display(reason)
        {:stop, :normal, state}
    end
  end
  def handle_info(:timeout, %{:list_socket => list_socket, :callback => cb} = state) do
    Logger.debug "handle_info timeout #{inspect cb}"
    {:ok, cli_socket} = :gen_tcp.accept(list_socket)
    Logger.debug "#{inspect list_socket}"
    create(list_socket, cb, false)
    case set_sockopt(list_socket, cli_socket) do
      :ok ->:ok
      {:error, reason} -> exit({:set_sockopt, reason})
    end
    :inet.setopts(cli_socket, [{:active, :once}, :binary])
    {:ok, client_ip_port} = :inet.peername(cli_socket)
    {:ok, server_ip_port} = :inet.sockname(cli_socket)
    Logger.debug "returning from timeout"
    {:noreply, %{state | :accepted => true, :cli_socket => cli_socket, :addr => {client_ip_port, server_ip_port}}}
  end

  @doc """
  Message handler for incoming STUN packets
  """
  def handle_info({:ssl, client, data}, state) do
    Logger.debug "handle_info ssl"
    {:ok, ip_port} = :ssl.peername(client)
    Logger.debug "TLS called from #{inspect ip_port} with #{inspect byte_size(data)} BYTES"
    return = handle_tcp_data(data, state)
    :ssl.setopts(client, [{:active, :once}, :binary])
    return
  end
  def handle_info({:tcp, client, data}, state) do
    Logger.debug "handle_info tcp"
    {:ok, ip_port} = :inet.peername(client)
    Logger.debug "TCP called from #{inspect ip_port} with #{inspect byte_size(data)} BYTES"
    return = handle_tcp_data(data, state)
    :inet.setopts(client, [{:active, :once}, :binary])
    return
  end

  def handle_info({:ssl_closed, client}, state) do
    Logger.debug "Client #{inspect client} closed connection"
    {:stop, :normal, state}
  end
  def handle_info({:tcp_closed, client}, state) do
    Logger.debug "Client #{inspect client} closed connection"
    {:stop, :normal, state}
  end

  def handle_info(info, state) do
    Logger.debug "TCP client: strange info: #{inspect info}"
    {:noreply, state}
  end

  def terminate(reason, %{:cli_socket => socket, :list_socket => list_socket, :callback => cb, :accepted => false, :ssl => ssl} = _state) do
    create(list_socket, cb, ssl)
    close(socket)
    Logger.debug "TCP client closed: #{reason}"
    :ok
  end
  def terminate(reason, %{:cli_socket => socket} = _state) do
    close(socket)
    Logger.debug "TCP client closed: #{reason}"
    :ok
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  @doc """
  Apply specific socket option for connection
  """
  def set_sockopt(list_sock, cli_socket) do
    true = :inet_db.register_socket(cli_socket, :inet_tcp)
    try do
      {:ok, opts} = :prim_inet.getopts(list_sock, [:active, :nodelay, :keepalive, :delay_send, :priority, :tos, :buffer, :recbuf, :sndbuf])
      :prim_inet.setopts(cli_socket, opts)
      :ok
    rescue
      e ->
        Logger.error "damn #{inspect e}"
        close(cli_socket)
    end
  end

  def handle_tcp_data(data, %{:msg_buffer => msg, :bucket => bucket} = state) do
    nbinary = <<msg::binary, data::binary>>
    
    case Queue.process_pkt(nbinary) do
      {:error, _} ->
        {:noreply, %{state | :msg_buffer => nbinary}}
      {:ok, pkt, clipped} ->
        Logger.info "#{inspect pkt}"
        case Queue.execute(pkt, bucket) do
          :ok ->
            {:noreply, %{state | :msg_buffer => clipped}}
          {:ok, resp} ->
            send_to_client(self, resp)
            {:noreply, %{state | :msg_buffer => clipped}}
          {:ok, :bucket_change, resp} ->
            send_to_client(self, resp)
            {:noreply, %{state | :msg_buffer => clipped, :bucket => pkt.data}}
          {:error, resp} ->
            send_to_client(self, resp)
            {:noreply, %{state | :msg_buffer => clipped}}
        end
    end
  end

  def send_msg({:sslsocket, _, _} = socket, msg) do
    :ssl.send(socket, msg)
  end
  def send_msg(socket, msg) do
    :gen_tcp.send(socket, msg)
  end

  def close(nil) do
    Logger.error "Caught attempted close of nil socket"
  end
  def close({:sslsocket, _, _} = socket) do
    :ssl.close(socket)
  end  
  def close(socket) when socket != nil do
    :gen_tcp.close(socket)
  end

end