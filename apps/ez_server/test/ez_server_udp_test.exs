defmodule EZ.Server.UDP.Test do
  use ExUnit.Case
  require Logger
  alias EZ.BiDS, as: BiDS
  alias EZ.Proto.BiDS.Client, as: Client

  defp send_msg(s, m), do: :gen_udp.send(s, {127,0,0,1}, 6379, m)

  test "udp_simple_string" do
    get_and_set("bar")
  end

  test "udp_simple_integer" do
    get_and_set(12345)
  end
  
  test "udp_simple_map" do
    get_and_set(%{"left" => "bar", "right" => "baz"})
  end
  
  test "udp_simple_boolean" do
    get_and_set(true)
  end

  defp get_and_set(value) do
    {:ok, socket} = :gen_udp.open(0, [:binary])
    simple = Client.set("0", "foo", value)
    send_msg(socket, simple)
    receive do
      {:udp, _, _, _, bin} ->
        {:ok, result} = BiDS.decode(bin)
        assert Client.is_success(result)
      after 2000 ->
        0
    end
    simple = Client.get("0", "foo")
    send_msg(socket, simple)
    receive do
      {:udp, _, _, _, bin} ->
        {:ok, result} = BiDS.decode(bin)
        assert Client.is_success(result)
        assert Client.value(result) == value
      after 2000 ->
        0
    end
  end
end
