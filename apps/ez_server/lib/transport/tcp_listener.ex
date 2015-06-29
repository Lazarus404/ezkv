defmodule EZ.Transport.TCP.Listener do
  @moduledoc """
  TCP protocol socket listener for STUN connections. Dispatches to TCP 
  clients once listener socket has been set up.
  """
  use GenServer
  require Logger
  @vsn "0"

  #####
  # External API

  @doc """
  Standard OTP module startup
  """
  def start_link(ip, port, cb, ssl \\ false) do
    GenServer.start_link(__MODULE__, [ip, port, cb, ssl])
  end

  @doc """
  Initialises connection with IPv6 address
  """
  def init([{i0, i1, i2, i3, i4, i5, i6, i7} = ipv6, port, cb, ssl]) when
    is_integer(i0) and i0 >= 0 and i0 < 65535 and
    is_integer(i1) and i1 >= 0 and i1 < 65535 and
    is_integer(i2) and i2 >= 0 and i2 < 65535 and
    is_integer(i3) and i3 >= 0 and i3 < 65535 and
    is_integer(i4) and i4 >= 0 and i4 < 65535 and
    is_integer(i5) and i5 >= 0 and i5 < 65535 and
    is_integer(i6) and i6 >= 0 and i6 < 65535 and
    is_integer(i7) and i7 >= 0 and i7 < 65535 do
    opts = [{:ip, ipv6}, :binary, {:reuseaddr, true}, {:keepalive, true}, {:backlog, 30}, {:active, false}, {:buffer, 1024*1024*16}, {:recbuf, 1024*1024*16}, {:sndbuf, 1024*1024*16}, :inet6]
    {:ok, socket} = case ssl do
      true ->
        {:ok, certs} = :application.get_env(:certs)
        nopts = opts ++ certs
        :ssl.listen(port, nopts)
      _ ->
        :gen_tcp.listen(port, opts)
    end
    EZ.Transport.TCP.Client.create(socket, cb, ssl)
    Logger.info "TCP listener started at [#{:inet_parse.ntoa(ipv6)}:#{port}]"
    {:ok, %{:listener => socket}}
  end

  @doc """
  Initialises connection with IPv4 address
  """
  def init([{i0, i1, i2, i3} = ipv4, port, cb, ssl]) when
    is_integer(i0) and i0 >= 0 and i0 < 256 and
    is_integer(i1) and i1 >= 0 and i1 < 256 and
    is_integer(i2) and i2 >= 0 and i2 < 256 and
    is_integer(i3) and i3 >= 0 and i3 < 256 do
    opts = [{:ip, ipv4}, :binary, {:reuseaddr, true}, {:keepalive, true}, {:backlog, 30}, {:buffer, 1024*1024*16}, {:recbuf, 1024*1024*16}, {:sndbuf, 1024*1024*16}, {:active, false}]
    {:ok, socket} = case ssl do
      true ->
        {:ok, certs} = :application.get_env(:certs)
        nopts = opts ++ certs
        :ssl.listen(port, nopts)
      _ ->
        :gen_tcp.listen(port, opts)
    end
    EZ.Transport.TCP.Client.create(socket, cb, ssl)
    Logger.info "TCP listener started at [#{:inet_parse.ntoa(ipv4)}:#{port}]"
    {:ok, %{:listener => socket}}
  end

  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end

  def terminate(reason, %{:listener => listener} = _state) do
    :erlang.display(reason)
    Logger.debug "TCP listener: terminating"
    :gen_tcp.close(listener)
    Logger.debug "TCP listener closed: #{reason}"
    :ok
  end

  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end
end