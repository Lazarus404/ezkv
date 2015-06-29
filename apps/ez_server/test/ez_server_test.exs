defmodule EZServerTest do
  use ExUnit.Case
  require Logger
  alias EZ.BiDS, as: BiDS

  test "udp_simple_set" do
  	{:ok, socket} = :gen_udp.open(0, [:binary])
  	simple = BiDS.make_pkt(:request, :set, [data_type: "string", key: "foo", data: "bar"])
  	out = BiDS.encode(simple)
    :gen_udp.send(socket, {127,0,0,1}, 6379, out)
    value = receive do
      {:udp, socket, _, _, bin} = msg ->
        Logger.info "client received: #{inspect msg}"
        {:ok, result} = BiDS.decode(bin)
        assert result = %EZ.BiDS{
        	class: :success,
        	fingerprint: false,
        	integrity: false,
        	key: nil,
        	method: :get
        }
        Logger.info "client decoded: #{inspect result}"
      after 2000 ->
        0
    end
  end

  test "udp_simple_get" do
  	{:ok, socket} = :gen_udp.open(0, [:binary])
  	simple = BiDS.make_pkt(:request, :get, [data_type: "string", key: "foo"])
  	out = BiDS.encode(simple)
    :gen_udp.send(socket, {127,0,0,1}, 6379, out)
    value = receive do
      {:udp, socket, _, _, bin} = msg ->
        Logger.info "client received: #{inspect msg}"
        {:ok, result} = BiDS.decode(bin)
        assert result = %EZ.BiDS{
        	class: :success,
        	fingerprint: false,
        	integrity: false,
        	key: nil,
        	method: :get
        }
        Logger.info "client decoded: #{inspect result}"
      after 2000 ->
        0
    end
  end
end
