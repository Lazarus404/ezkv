defmodule EZ.Server.TCP.Test do
  use ExUnit.Case
  require Logger
  alias EZ.BiDS, as: BiDS
  alias EZ.Proto.BiDS.Client, as: Client

  @timeout 1000

  test "tcp_simple_string" do
    get_and_set("bar")
  end

  test "tcp_simple_integer" do
    get_and_set(12345)
  end
  
  test "tcp_simple_map" do
    get_and_set(%{"left" => "bar", "right" => "baz"})
  end
  
  test "tcp_simple_boolean" do
    get_and_set(true)
  end

  defp send_msg(s, m), do: :gen_tcp.send(s, m)
  
  def recv(s, buf \\ <<>>) do
    case :gen_tcp.recv(s, 0, @timeout) do
      {:ok, bin} ->
        nbinary = <<bin::binary, buf::binary>>
        case process_pkt(nbinary) do
          {:error, _} ->
            recv(s, nbinary)
          {:ok, pkt, clipped} ->
            # we're only expecting one packet
            {:ok, pkt}
          r -> r
        end
      {:error, :timeout} ->
        Logger.info "timeout"
        recv(s, buf)
      {:error, reason} ->
        exit(reason)
    end
  end

  defp process_pkt(pkt) do
    bin_bytes = byte_size(pkt)
    cond do
      bin_bytes <= 4  ->
        {:error, :partial}
      true ->
        case pkt do
          <<3::2, _::14, body_bytes::16, _body::binary-size(body_bytes), _::binary>> ->
            padded_msg_bytes = body_bytes + 20
            cond do
              padded_msg_bytes > bin_bytes  ->
                # need more data
                {:error, :partial}
              padded_msg_bytes == bin_bytes ->
                {:ok, pkt}
              true ->
                <<bids::binary-size(padded_msg_bytes), tail::binary>> = pkt
                {:ok, bids}
            end
          <<3::2, _::14, _body_bytes::16, _::binary>> -> # message is not yet long enough
            {:error, :partial}
          <<type::2, _::14, _::binary>> ->
            {:error, :invalid_packet}
        end
    end
  end

  defp get_and_set(value) do
    {:ok, socket} = :gen_tcp.connect({127,0,0,1}, 6379, [:binary, active: false])
    simple = Client.set("0", "foo", value)
    send_msg(socket, simple)
    case recv(socket) do
      {:ok, bin} ->
        {:ok, result} = BiDS.decode(bin)
        assert Client.is_success(result)
      _ ->
        assert false
    end
    simple = Client.get("0", "foo")
    send_msg(socket, simple)
    case recv(socket) do
      {:ok, bin} ->
        {:ok, result} = BiDS.decode(bin)
        assert Client.is_success(result)
        assert Client.value(result) == value
      _ ->
        assert false
    end
  end
end
