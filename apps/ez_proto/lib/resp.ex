defmodule EZ.Proto.RESP do
  alias EZ.Proto.RESP, as: Proto
  require Logger

  defstruct cmd: nil, data: nil, bucket: nil

  def new(pkt) do
    case Proto.process(pkt) do
      {:ok, [cmd|[data]], buf} ->
        {:ok, %EZ.Proto.RESP{
          cmd: cmd |> String.downcase |> String.to_atom, 
          data: data
        }, buf}
      {:ok, [cmd|data], buf} ->
        {:ok, %EZ.Proto.RESP{
          cmd: cmd |> String.downcase |> String.to_atom, 
          data: data
        }, buf}
      :partial -> {:error, :partial}
    end
  end

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

defimpl EZ.Proto.PktProto, for: EZ.Proto.RESP do
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

  # def encode(_, :ok, str) when is_binary(str), do: <<"+", str::binary, @nl::binary>>
  # def encode(_, :simple, str) when is_binary(str), do: <<"+", str::binary, @nl::binary>>
  # def encode(_, :int, int) when is_integer(int), do: <<":#{int}", @nl::binary>>
  # def encode(_, :error, str) when is_binary(str), do: <<"-#{str}", @nl::binary>>
  # def encode(_, :bulk, nil), do: <<"$-1", @nl::binary>>
  # def encode(_, :bulk, str) when is_binary(str), do: <<"$#{byte_size(str)}", @nl::binary, str::binary, @nl::binary>>
end