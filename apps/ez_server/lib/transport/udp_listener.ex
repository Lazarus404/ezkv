defmodule EZ.Transport.UDP.Listener do
  @moduledoc """
  UDP protocol socket handler for STUN connections
  """
  use GenServer
  require Logger
  alias EZ.Queue.Manager, as: Queue
  @vsn "0"

  #####
  # External API

  @doc """
  Standard OTP module startup
  """
  def start_link(ip, port, cb, ssl \\ false) do
    GenServer.start_link(__MODULE__, [ip, port, cb, ssl], [debug: [:statistics]])
  end

  @doc """
  Initialises connection with IPv6 address
  """
  def init([{i0, i1, i2, i3, i4, i5, i6, i7} = ipv6, port, cb, _ssl]) when
    is_integer(i0) and i0 >= 0 and i0 < 65535 and
    is_integer(i1) and i1 >= 0 and i1 < 65535 and
    is_integer(i2) and i2 >= 0 and i2 < 65535 and
    is_integer(i3) and i3 >= 0 and i3 < 65535 and
    is_integer(i4) and i4 >= 0 and i4 < 65535 and
    is_integer(i5) and i5 >= 0 and i5 < 65535 and
    is_integer(i6) and i6 >= 0 and i6 < 65535 and
    is_integer(i7) and i7 >= 0 and i7 < 65535 do
    {:ok, fd} = :gen_udp.open(port, [{:ip, ipv6}, {:active, false}, {:buffer, 1024*1024*16}, {:recbuf, 1024*1024*16}, {:sndbuf, 1024*1024*16}, :binary, :inet6])
    Logger.info "UDP listener #{inspect self()} started at [#{:inet_parse.ntoa(ipv6)}:#{port}]"
    {:ok, %{:socket => fd, :callback => cb}, 0}#, :pid => pid}}
  end

  @doc """
  Initialises connection with IPv4 address
  """
  def init([{i0, i1, i2, i3} = ipv4, port, cb, _ssl]) when
    is_integer(i0) and i0 >= 0 and i0 < 256 and
    is_integer(i1) and i1 >= 0 and i1 < 256 and
    is_integer(i2) and i2 >= 0 and i2 < 256 and
    is_integer(i3) and i3 >= 0 and i3 < 256 do
    {:ok, fd} = :gen_udp.open(port, [{:ip, ipv4}, {:active, false}, {:buffer, 1024*1024*1024}, {:recbuf, 1024*1024*1024}, {:sndbuf, 1024*1024*1024}, :binary])
    Logger.info "UDP listener #{inspect self()} started at [#{:inet_parse.ntoa(ipv4)}:#{port}]"
    {:ok, %{:socket => fd, :callback => cb}, 0}#, :pid => pid}}
  end

  def handle_call(other, _from, state) do
    Logger.error "UDP listener: strange call: #{inspect other}"
    {:noreply, state}
  end

  @doc """
  Asynchronous socket response handler  
  """
  def handle_cast({msg, ip, port}, state) do
    :gen_udp.send(state.socket, ip, port, msg)
    {:noreply, state}
  end

  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end

  def handle_cast(other, state) do
    Logger.error "UDP listener: strange cast: #{inspect other}"
    {:noreply, state}
  end

  def handle_info(:timeout, state) do
    :inet.setopts(state.socket, [{:active, :once}, :binary])
    :erlang.process_flag(:priority, :high)
    {:noreply, state}
  end
  
  @doc """
  Message handler for incoming STUN packets
  """
  def handle_info({:udp, _fd, fip, fport, msg}, state) do
    Logger.debug "UDP called #{inspect byte_size(msg)} bytes"
    # {:ok, {tip, tport}} = :inet.sockname(state.socket)
    case Queue.process_pkt(msg) do
      {:error, _} ->
        {:noreply, state}
      {:ok, pkt, _} ->
        Logger.info "#{inspect pkt}"
        case Queue.execute(pkt) do
          :ok ->
            {:noreply, state}
          {:ok, resp} ->
            GenServer.cast(self, {resp, fip, fport})
            {:noreply, state}
          {:error, resp} ->
            GenServer.cast(self, {resp, fip, fport})
            {:noreply, state}
        end
      oops -> Logger.info "OOPS: #{inspect oops}"
    end
    # spawn(state.callback, :process_message, [msg, {self(), fip, fport, tip, tport}])
    :inet.setopts(state.socket, [{:active, :once}, :binary])
    :erlang.process_flag(:priority, :high)
    {:noreply, state}
  end

  def handle_info(info, state) do
    Logger.error "UDP listener: strange info: #{inspect info}"
    {:noreply, state}
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  def terminate(reason, state) do
    :gen_udp.close(state.socket)
    Logger.debug "UDP listener closed: #{inspect reason}"
    :ok
  end
end