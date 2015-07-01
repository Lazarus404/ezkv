defprotocol EZ.Proto.PktProto do
  @moduledoc """
  Polymorphism interface declaration for pkt types
  """
  def encode(pkt)
  def encode(pkt, cmd, data)
end

defmodule EZ.Proto.Pkt do
  alias EZ.Proto.RESP.Pkt, as: RESP
  alias EZ.Proto.BiDS.Pkt, as: BiDS

  @doc """
  Determine incoming packet type. Since RESP packet commands
  use the lower end of the ascii chart, we can distinguish BiDS
  packets as those whose first byte has two preceeding bits set.
  """
  def from_wire(<<3::2, _::6, _::24, 0x56E44E21::32, _::binary>> = pkt), do: BiDS.new(pkt)
  def from_wire(pkt), do: RESP.new(pkt)

  def encode(pkt), do: EZ.Proto.PktProto.encode(pkt)
  def encode(pkt, cmd, data), do: EZ.Proto.PktProto.encode(pkt, cmd, data)
end