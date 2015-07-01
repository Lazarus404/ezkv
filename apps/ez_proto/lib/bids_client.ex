defmodule EZ.Proto.BiDS.Client do
  @moduledoc """
  utility interface to simplify handling bids packets
  """
  require Logger
  alias EZ.BiDS

  @doc """
  creates a packet object for encoding
  """
  def make_pkt(class, method, attrs \\ [], key \\ nil) do
    %BiDS{
      attrs: attrs, 
      class: class,
      fingerprint: (key != nil), 
      integrity: (key != nil),
      key: key,
      method: method, 
      transactionid: gen_trans_id
    }
  end

  @doc """
  converts a bids map value to an error and 
  appends an error attribute tuple
  """
  def error(%BiDS{} = pkt, code, reason) when is_integer(code) and is_binary(reason) do
    attrs = Map.get(pkt, :attrs, [])
    |> Keyword.put(:error, {code, reason})
    Map.put(pkt, :attrs, attrs)
    |> Map.put(:class, :error)
  end

  @doc """
  converts a bids map value to a response and 
  updates its data attribute to the passed value
  """
  def success(%BiDS{} = pkt) do
    pkt |> Map.put(:class, :success)
  end
  def success(%BiDS{} = pkt, type, value) do
    attrs = Map.get(pkt, :attrs, [])
    |> Keyword.put(:data, value)
    |> Keyword.put(:data_type, type)
    Map.put(pkt, :attrs, attrs)
    |> Map.put(:class, :success)
  end

  def is_success(%BiDS{class: :success}), do: true
  def is_success(%BiDS{}), do: false

  @doc """
  creates a request object with the method "get".
  used to retrieve a value from a key
  """
  def get(bucket, key), do: make_pkt(:request, :get, [bucket: bucket, key: key]) |> BiDS.encode

  @doc """
  creates a request object with the method "set"
  used to set a value to a key
  """
  def set(bucket, key, value) when is_binary(value), do:
    make_pkt(:request, :set, [bucket: bucket, key: key, data: value, data_type: "string"]) |> BiDS.encode
  def set(bucket, key, value) when is_integer(value), do:
    make_pkt(:request, :set, [bucket: bucket, key: key, data: "#{value}", data_type: "int"]) |> BiDS.encode
  def set(bucket, key, value), do:
    make_pkt(:request, :set, [bucket: bucket, key: key, data: Poison.encode!(value), data_type: "json"]) |> BiDS.encode

  @doc """
  creates a request object with the method "del"
  used to delete a key / value pair
  """
  def del(bucket, key), do: make_pkt(:request, :del, [bucket: bucket, key: key]) |> BiDS.encode

  def value(%BiDS{} = pkt) do
    attrs = pkt.attrs
    d = Dict.get(attrs, :data)
    dt = Dict.get(attrs, :data_type)
    case dt do
      nil -> d
      "int" when is_integer(d) -> d
      "int" when is_binary(d) -> String.to_integer(d)
      "string" when is_binary(d) -> d
      "json" when is_binary(d) -> Poison.decode!(d)
      "empty" -> d
    end
  end

  def get_response() do

  end

  def set_response() do

  end

  def del_response() do

  end

  @doc """
  returns a 12 byte transaction id value
  """
  def gen_trans_id do
    <<b::96>> = :crypto.strong_rand_bytes(12)
    b
  end
end