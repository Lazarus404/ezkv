defmodule EZ.Queue.Client do
  use GenServer
  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def create() do
    EZ.Queue.Supervisor.start_child()
  end

  def destroy(pid) do
    EZ.Queue.Supervisor.terminate_child(pid)
  end

  #########################################################################################################################
  # OTP functions
  #########################################################################################################################

  def init([]) do
  	{:ok, %{bucket: HashDict.new}}
  end

  def handle_call({:get, key}, _from, %{bucket: bucket} = state) do
    case HashDict.get(bucket, key, nil) do
      nil -> {:reply, {:error, nil}, state}
      val -> {:reply, {:ok, val}, state}
    end
  end

  def handle_call({:set, [key, value]}, _from, %{bucket: bucket} = state) do
    {:reply, :ok, %{state | bucket: HashDict.put(bucket, key, value)}}
  end

  def handle_call({:del, key}, _from, %{bucket: bucket} = state) do
    case Dict.has_key?(bucket, key) do
      true ->
      	{:reply, {:ok, 1}, %{state | bucket: HashDict.delete(bucket, key)}}
      false ->
      	{:reply, {:ok, 0}, %{state | bucket: HashDict.delete(bucket, key)}}
    end
  end

  def handle_call({a, b}, _from, state) do
    {:reply, {:error, "#{a}, #{b}"}, state}
  end
end