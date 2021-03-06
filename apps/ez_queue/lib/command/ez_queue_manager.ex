defmodule EZ.Queue.Manager do
  @moduledoc """
  handles the outer db, such as db selection and packet process handling.
  """
  use GenServer
  alias EZ.Queue.Client
  alias EZ.Proto.Pkt
  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Acquire packet from binary stream here, since
  we don't want to pollute container apps with knowledge of
  packet functions.
  """
  def process_pkt(pkt) do
    Pkt.from_wire(pkt)
  end

  @doc """
  attempt to execute the command depicted by the packet structure
  """
  def execute(pkt, db \\ nil) do
    case do_execute(pkt.cmd, pkt.data, pkt.bucket || db) do
      {:bucket_change, value} -> {:ok, :bucket_change, Pkt.encode(pkt, :ok, nil)}
      {status, value} -> {:ok, Pkt.encode(pkt, status, value)}
      :ok -> {:ok, Pkt.encode(pkt, :ok, nil)}
    end
  end

  def do_execute(cmd, data, bucket) do
    GenServer.call(EZ.Queue.Manager, {cmd, data, bucket})
  end

  #########################################################################################################################
  # OTP functions
  #########################################################################################################################

  def init([]) do
    {:ok, default} = Client.create
    {:ok, %{"0" => default}}
  end

  @doc """
  Switch bucket. Create if not exists.
  """
  def handle_call({:select, id, _bucket}, _from, state) do
    case Dict.has_key?(state, id) do
      true ->
        Logger.info "setting bucket #{inspect id}"
        {:reply, {:bucket_change, id}, state}
      _ ->
        case Client.create() do
          {:ok, child} ->
            Logger.info "creating bucket #{inspect id}"
            {:reply, {:bucket_change, id}, Dict.put(state, id, child)}
          _ ->
            Logger.info "error with bucket #{inspect id}"
            {:reply, {:error, :invalid_bucket_index}, state}
        end
    end
  end

  @doc """
  Forward execution to flagged bucket process
  """
  def handle_call({cmd, value, db}, _from, state) do
    case Dict.has_key?(state, db) && Process.alive?(Dict.get(state, db)) do
      true ->
        :ok
      _ ->
        Logger.info "#{cmd}, #{db}, #{inspect state}"
        GenServer.call(self, {:select, db, nil})
    end
    {:reply, GenServer.call(Dict.get(state, db), {cmd, value}), state}
  end
end