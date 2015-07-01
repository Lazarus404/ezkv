defmodule EZ.Proto.RESP.Pkt do
  @moduledoc """
  Polymorphosed pkt handler for Redis RESP format
  """
  alias EZ.Proto.RESP.Pkt, as: Proto
  require Logger

  defstruct cmd: nil, data: nil, bucket: nil

  @doc """
  create RESP map structure from RESP string
  """
  def new(pkt) do
    case Proto.process(pkt) do
      {:ok, [cmd|[data]], buf} ->
        {:ok, %EZ.Proto.RESP.Pkt{
          cmd: cmd |> String.downcase |> String.to_atom, 
          data: data
        }, buf}
      {:ok, [cmd|data], buf} ->
        {:ok, %EZ.Proto.RESP.Pkt{
          cmd: cmd |> String.downcase |> String.to_atom, 
          data: data
        }, buf}
      :partial -> {:error, :partial}
    end
  end

  @doc """
  Here, process supports the full RESP format, but we don't
  support the arrays in the Queue app, since we support JSON.
  """
  def process(<<"+", data::binary>> = pkt) do
    case nibble(data, 2) do
      ^data -> {:error, pkt}
      [str, buf] -> {:ok, str, buf}
    end
  end

  def process(<<"-", data::binary>> = pkt) do
    case nibble(data, 2) do
      ^data -> {:error, pkt}
      [str, buf] -> {:ok, str, buf}
    end
  end

  def process(<<":", data::binary>> = pkt) do
    case nibble(data, 2) do
      ^data -> {:error, pkt}
      [int, buf] -> {:ok, String.to_integer(int), buf}
    end
  end

  def process(<<"$", data::binary>> = pkt) do
    case nibble(data, 2) do
      ^data -> {:error, pkt}
      ["-1", buf] -> {:ok, nil, buf}
      [_size, buf] ->
        case nibble(buf, 2) do
          ^buf -> {:error, pkt}
          [str, buf] -> {:ok, str, buf}
        end
    end
  end

  def process(<<"*", data::binary>> = pkt) do
    case nibble(data, 2) do
      ^data -> {:error, pkt}
      ["-1", buf] -> {:ok, nil, buf}
      [size, buf] -> 
        case consume(buf, String.to_integer(size)) do
          :error -> {:error, pkt}
          list -> list
        end
    end
  end

  # Private funcs

  defp consume(buf, size, acc \\ [])
  defp consume(buf, size, acc) when size == 0, do: {:ok, acc, buf}
  defp consume(buf, size, acc) do
    case process(buf) do
      {:error, _} -> :error
      {:ok, val, buf} -> consume(buf, size-1, acc ++ [val])
    end
  end

  defp nibble(buf, parts), do: Regex.split(~r/\r\n/, buf, [parts: parts])
end

defimpl EZ.Proto.PktProto, for: EZ.Proto.RESP.Pkt do
  @moduledoc """
  Polymorphed functions interface for outgoing packet encoding
  """
  @nl "\r\n"
  def encode(_), do: <<"+OK", @nl::binary>>
  def encode(pkt, type, val \\ nil)
  def encode(_, :ok, val) do
    cond do
      val == nil -> <<"+OK", @nl::binary>>
      is_integer(val) -> <<":#{val}", @nl::binary>>
      is_binary(val) -> <<"$#{byte_size(val)}", @nl::binary, val::binary, @nl::binary>>
      true -> <<"+OK", @nl::binary>>
    end
  end
  def encode(_, :error, nil), do: <<"$-1", @nl::binary>>
  def encode(_, :error, str) when is_binary(str), do: <<"-#{str}", @nl::binary>>
end