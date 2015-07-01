defprotocol EZ.Proto.PktProto do
  def encode(pkt)
  def encode(pkt, cmd, data)
end

defmodule EZ.Proto.Pkt do
  alias EZ.Proto.RESP.Pkt, as: RESP
  alias EZ.Proto.BiDS.Pkt, as: BiDS

  def from_wire(<<3::2, _::6, _::24, 0x56E44E21::32, _::binary>> = pkt), do: BiDS.new(pkt)
  def from_wire(pkt), do: RESP.new(pkt)

  def encode(pkt), do: EZ.Proto.PktProto.encode(pkt)
  def encode(pkt, cmd, data), do: EZ.Proto.PktProto.encode(pkt, cmd, data)
end