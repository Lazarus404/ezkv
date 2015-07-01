defmodule EZ.Queue.Client do
  @moduledoc """
  Bucket process, identifiable by name
  """
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
    Logger.info "GET CALLED: #{inspect key}, #{inspect bucket}"
    case HashDict.get(bucket, key, nil) do
      nil -> {:reply, {:error, "does not exist"}, state}
      val -> {:reply, {:ok, val}, state}
    end
  end

  def handle_call({:set, [key, value]}, _from, %{bucket: bucket} = state) do
    Logger.info "SET CALLED: #{inspect key}, #{inspect value}, #{inspect bucket}"
    {:reply, :ok, %{state | bucket: HashDict.put(bucket, key, value)}}
  end

  def handle_call({:del, key}, _from, %{bucket: bucket} = state) do
    Logger.info "DEL CALLED: #{inspect key}, #{inspect bucket}"
    case Dict.has_key?(bucket, key) do
      true ->
      	{:reply, {:ok, 1}, %{state | bucket: HashDict.delete(bucket, key)}}
      false ->
      	{:reply, {:ok, 0}, %{state | bucket: HashDict.delete(bucket, key)}}
    end
  end

  def handle_call({a, b}, _from, state) do
    Logger.info "UNKNOWN TYPE: #{inspect a} : #{inspect b}"
    {:reply, {:error, "#{a}, #{b}"}, state}
  end
end