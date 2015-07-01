defmodule EZ.Proto.BiDS.Pkt do
  require Logger
  alias EZ.BiDS, as: BiDS

  defstruct cmd: nil, data: nil, bucket: nil, request: nil

  def new(pkt) when is_binary(pkt) do
    bin_bytes = byte_size(pkt)
    cond do
      bin_bytes <= 4  ->
        {:error, :partial}
      true ->
        case pkt do
          <<3::2, _::14, body_bytes::16, _body::binary-size(body_bytes), _::binary>> ->
            padded_msg_bytes = body_bytes + 20
            Logger.debug "padded_msg_bytes::bin_bytes -> #{inspect padded_msg_bytes}, #{inspect bin_bytes}"
            cond do
              padded_msg_bytes > bin_bytes  ->
                # need more data
                {:error, :partial}
              padded_msg_bytes == bin_bytes ->
                {:ok, process(pkt), <<>>}
              true ->
                <<bids::binary-size(padded_msg_bytes), tail::binary>> = pkt
                Logger.debug "Tail is: #{inspect tail}"
                {:ok, process(bids), tail}
            end
          <<3::2, _::14, _body_bytes::16, _::binary>> -> # message is not yet long enough
            {:error, :partial}

          <<type::2, _::14, _::binary>> ->
            Logger.error "Unknown message type : #{inspect type}"
            {:error, :invalid_packet}
        end
    end
  end

  defp process(pkt) do
    {:ok, %BiDS{class: :request, attrs: attrs, method: cmd} = req} = BiDS.decode(pkt)
      data = Dict.get(attrs, :data, nil)
      key = Dict.get(attrs, :key, "")
      decoded = case Dict.get(attrs, :data_type) do
        "json" -> json(key, data)
        "string" -> string(key, data)
        "int" -> int(key, data)
        _ -> key
      end
      bucket = Dict.get(attrs, :bucket, "0")
      %EZ.Proto.BiDS.Pkt{cmd: cmd, data: decoded, bucket: bucket, request: req}
  end

  defp json(k, v) do
    case v do
      nil -> k
      d -> [k, {:json, Poison.decode!(d)}]
    end
  end

  defp int(k, v) do
    case v do
      nil -> k
      d -> [k, {:int, String.to_integer(d)}]
    end
  end

  defp string(k, v) do
    case v do
      nil -> k
      d -> [k, {:string, d}]
    end
  end
end

defimpl EZ.Proto.PktProto, for: EZ.Proto.BiDS.Pkt do
  alias EZ.Proto.BiDS.Client
  def encode(%EZ.Proto.BiDS.Pkt{} = pkt), do: EZ.BiDS.encode(pkt)
  def encode(%EZ.Proto.BiDS.Pkt{} = pkt, :error, str) when is_binary(str) do
    Client.error(pkt.request, 100, str)
    |> EZ.BiDS.encode
  end
  def encode(%EZ.Proto.BiDS.Pkt{} = pkt, :error, str) when is_atom(str) do
    Client.error(pkt.request, 100, to_string(str))
    |> EZ.BiDS.encode
  end
  def encode(%EZ.Proto.BiDS.Pkt{} = pkt, :ok, val) when is_integer(val) do
    Client.success(pkt.request, "int", "#{val}")
    |> EZ.BiDS.encode
  end
  def encode(%EZ.Proto.BiDS.Pkt{} = pkt, :ok, val) when is_binary(val) do
    Client.success(pkt.request, "string", val)
    |> EZ.BiDS.encode
  end
  def encode(%EZ.Proto.BiDS.Pkt{} = pkt, :ok, {type, val}) do
    case type do
      :int -> Client.success(pkt.request, "int", "#{val}")
      :string -> Client.success(pkt.request, "string", val)
      :json -> Client.success(pkt.request, "json", Poison.encode!(val))
      _ -> Client.error(pkt.request, 100, "unknown type")
    end
    |> EZ.BiDS.encode
  end
  def encode(%EZ.Proto.BiDS.Pkt{} = pkt, :ok, val) do
    case val do
      nil -> Client.success(pkt.request)
      _ -> Client.success(pkt.request, "json", Poison.encode!(val))
    end
    |> EZ.BiDS.encode
  end
  
  # def encode(_, :ok, nil), do: <<"+OK", @nl::binary>>
  # def encode(_, :ok, str) when is_binary(str), do: <<"+", str::binary, @nl::binary>>
  # def encode(_, :simple, str) when is_binary(str), do: <<"+", str::binary, @nl::binary>>
  # def encode(_, :int, int) when is_integer(int), do: <<":#{int}", @nl::binary>>
  # def encode(_, :error, str) when is_binary(str), do: <<"-#{str}", @nl::binary>>
  # def encode(_, :bulk, nil), do: <<"$-1", @nl::binary>>
  # def encode(_, :bulk, str) when is_binary(str), do: <<"$#{byte_size(str)}", @nl::binary, str::binary, @nl::binary>>
end