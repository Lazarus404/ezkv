defmodule EZ.BiDS do #Binary delivery stream
  use Bitwise
  require Logger
  @moduledoc """
  The Bids module copies from several the RFC protocols for both encoding and decoding.
  """

  @doc """
  Used by BiDS to tag a packet as 
  specifically of a BiDS format.
  """
  @bids_marker 3
  @bids_magic_cookie 0x56E44E21

  @moduledoc """
  BiDS object structure for per-connection usage
  """
  defstruct class: nil,
            method: nil, 
            transactionid: nil, 
            integrity: :false, 
            key: nil, 
            fingerprint: :true, 
            attrs: []

  @doc """
  Accepts a BiDS binary stream and attempts to convert it to readable
  packets for use by the greater application.
  ## Example
        iex> request = <<1, 1, 0, 0, 33, 18, 164, 66, 0, 146, 225, 0, 
        ...> 61, 62, 163, 87, 45, 150, 223, 8>>
        iex> EZ.BiDS.decode(request)
        {:ok, %BiDS{attrs: [], class: :request, fingerprint: false, 
        integrity: false, key: nil, method: :binding, 
        transactionid: 177565706535525809372192520}}
  """
  def decode(bids_binary, key \\ nil) do
      {fingerprint, rest} = check_fingerprint(bids_binary)
      {integrity, rest2} = check_integrity(rest, key)
      process_bids(rest2, key, fingerprint, integrity)
  end

  def process_bids(bids_binary, key, fingerprint, integrity) do
    <<@bids_marker::2, m0::5, c0::1, m1::3, c1::1, m2::4, length::16, @bids_magic_cookie::32, transactionid::96, rest3::binary>> = bids_binary
    method = get_method(<<m0::size(5), m1::size(3), m2::size(4)>>)
    class = get_class(<<c0::size(1), c1::size(1)>>)
    attrs = decode_attrs(rest3, length, transactionid, [])
    {:ok, %EZ.BiDS{class: class, method: method, integrity: integrity, key: key, transactionid: transactionid, fingerprint: fingerprint, attrs: attrs}}
  end

  @doc """
  Accepts data and attempts to convert it to a BiDS specific
  stream as a response to the calling client.
  ## Example
        iex> response = %BiDS{class: :request, method: :set, 
        ...> transactionid: 123456789012, fingerprint: false, attrs: [
        ...>   {:data, "bar"}
        ...> ]}
        iex> EZ.BiDS.encode(response)
        <<1, 1, 0, 52, 33, 18, 164, 66, 0, 0, 0, 0, 0, 0, 0, 28, 190, 153, 
        26, 20, 0, 32, 0, 8, 0, 1, 17, 43, 94, 18, 164, 67, 0, 1, 0, 8, 0, 
        1, 48, 57, 127, 0, 0, 1, 0, 4, 0, 8, 0, 1, 48, 58, 127, 0, 0, 1, 
        128, 34, 0, 11, 120, 105, 114, 115, 121, 115, 45, 115, 116, 117, 
        110, 0>>
  """
  def encode(%EZ.BiDS{} = config, nkey \\ nil) do
    # Logger.info "BIDS_CONN #{inspect config}"
    m = get_method_id(config.method)
    <<m0::size(5), m1::size(3), m2::size(4)>> = <<m::size(12)>>
    <<c0::size(1), c1::size(1)>> = get_class_id(config.class)

    bin_attrs = for {t, v} <- config.attrs, into: "", do: encode_bin(encode_attribute(t, v, config.transactionid))
    length = byte_size(bin_attrs)

    bids_binary_0 = <<@bids_marker::size(2), m0::size(5), c0::size(1), m1::size(3), c1::size(1), m2::size(4), length::16, @bids_magic_cookie::32, config.transactionid::96, bin_attrs::binary>>

    bids_binary_1 = case config.integrity do
      false -> bids_binary_0
      true -> 
        case nkey do
          nil ->
            bids_binary_0
          _ -> 
            insert_integrity(bids_binary_0, nkey)
        end
    end

    case config.fingerprint do
      false -> bids_binary_1
      true -> insert_fingerprint(bids_binary_1)
    end
  end

  # -------------------------------------------------------------------------------
  # Start code generation
  # -------------------------------------------------------------------------------

  @external_resource attrs_path = Path.join([__DIR__, "../priv/bids-attrs.txt"])
  @external_resource methods_path = Path.join([__DIR__, "../priv/bids-methods.txt"])
  @external_resource classes_path = Path.join([__DIR__, "../priv/bids-classes.txt"])

  @doc """
  Encodes an attribute tuple into a new tuple representing its type and
  an encoded binary representation of its value
  """
  for line <- File.stream!(attrs_path, [], :line) do
    [byte, name, type] = line |> String.split("\t") |> Enum.map(&String.strip(&1))

    case type do
      "value" ->
        def decode_attribute(unquote(String.to_integer(byte)), value, _), do: {String.to_atom(unquote(name)), value}
        def encode_attribute(unquote(String.to_atom(name)), value, _), do: {String.to_integer(unquote(byte)), value}
      "coded_value" ->
        def decode_attribute(unquote(String.to_integer(byte)), value, tid), do: {String.to_atom(unquote(name)), decode_attr_tuple(value)}
        def encode_attribute(unquote(String.to_atom(name)), value, _), do: {String.to_integer(unquote(byte)), encode_attr_tuple(value)}
    end
  end

  def decode_attribute(byte, value, _) do
    Logger.error "Could not find match for #{inspect byte}"
    {byte, value}
  end
  def encode_attribute(other, value, _) do
    Logger.error "Could not find match for #{inspect other}"
    {other, value}
  end

  @doc """
  Provides packet method type based on id and vice versa
  """
  for line <- File.stream!(methods_path, [], :line) do
    [id, name] = line |> String.split("\t") |> Enum.map(&String.strip(&1))

    def get_method(<<unquote(String.to_integer(id))::size(12)>>), do: unquote(String.to_atom(name))
    def get_method_id(unquote(String.to_atom(name))), do: unquote(String.to_integer(id))
  end

  def get_method(<<o::size(12)>>), do: o
  def get_method_id(o), do: o

  @doc """
  Provides packet class type based on id and vice versa
  """
  for line <- File.stream!(classes_path, [], :line) do
    [id, name] = line |> String.split("\t") |> Enum.map(&String.strip(&1))

    def get_class(<<unquote(String.to_integer(id))::size(2)>>), do: unquote(String.to_atom(name))
    def get_class_id(unquote(String.to_atom(name))), do: <<unquote(String.to_integer(id))::2>>
  end

  # -------------------------------------------------------------------------------
  # End code generation
  # -------------------------------------------------------------------------------


  #####
  # BiDS decoding helpers
  
  @doc """
  Converts a given binary encoded list of attributes into an Erlang list of tuples
  """
  def decode_attrs(<<>>, 0, _, attrs) do
    attrs
  end
  def decode_attrs(<<>>, length, _, attrs) do
    Logger.info "FIXME: BiDS TLV wrong length #{length}"
    attrs
  end
  def decode_attrs(<<type::size(16), item_length::size(32), bin::binary>>, length, tid, attrs) do
    padding_length = case rem(item_length, 4) do
      0 -> 0
      other ->
        case item_length == byte_size(bin) do
          true -> 0
          _ -> 4 - other
        end
    end
    <<value::binary-size(item_length), _::binary-size(padding_length), rest::binary>> = bin
    {t,v} = decode_attribute(type, value, tid)
    new_length = length - (2 + 2 + item_length + padding_length)
    decode_attrs(rest, new_length, tid, attrs ++ [{t, v}])
  end

  @doc """
  Converts a given binary encoded error into an Erlang tuple
  """
  def decode_attr_tuple(<<_mbz::size(20), class::size(4), number::size(8), reason::binary>>) do
    {class*100 + number, reason}
  end

  #####
  # Encoding helpers

  @doc """
  Encodes an attribute tuple into its specific encoded binary
  """
  def encode_bin({t, v}) do
    l = byte_size(v)
    padding_length = case rem(l, 4) do
      0 -> 0
      other -> (4 - other)*8
    end
    <<t::16, l::32, v::binary-size(l), 0::size(padding_length)>>
  end

  @doc """
  Encodes a BiDS error tuple into its binary representation
  """
  def encode_attr_tuple({error_code, reason}) do
    class = div(error_code, 100)
    number = rem(error_code, 100)
    <<0::size(20), class::size(4), number::size(8), reason::binary>>
  end

  #####
  # Fingerprinting and auth

  @doc """
  Checks if a raw BiDS binary contains a fingerprint. If so, removes the
  fingerprint and re-hashes ready for an integrity check
  """
  def check_fingerprint(bids_binary) do
    s = byte_size(bids_binary) - 8
    case bids_binary do
      <<message::binary-size(s), 0x80::8, 0x28::8, 0x00::8, 0x04::8, crc::32>> ->
        # Die if CRC doesn't match
        try do
          ^crc = bxor(:erlang.crc32(message), 0x5354554e)
          <<h::size(16), old_size::size(16), payload::binary>> = message
          new_size = old_size - 8
          {true, <<h::size(16), new_size::size(16), payload::binary>>}
        rescue
          _ -> {false, bids_binary}
        end
      _ ->
        Logger.debug "No CRC was found in a BiDS message."
        {false, bids_binary}
    end
  end

  @doc """
  Applies a fingerprint to a BiDS binary
  """
  def insert_fingerprint(bids_binary) do
    <<h::size(16), _::size(16), message::binary>> = bids_binary
    s = byte_size(bids_binary) + 8 - 20
    crc = bxor(:erlang.crc32(<<h::size(16), s::size(16), message::binary>>), 0x5354554e)
    <<h::size(16), s::size(16), message::binary, 0x80::size(8), 0x28::size(8), 0x00::size(8), 0x04::size(8), crc::size(32)>>
  end

  @doc """
  Checks for an integrity marker and its validity in a BiDS binary

  Must be called AFTER check_fingerprint
  """
  def check_integrity(bids_binary) do
    s = byte_size(bids_binary) - 24
    case bids_binary do
      <<message::binary-size(s), 0x00::size(8), 0x08::size(8), 0x00::size(8), 0x14::size(8), fingerprint::binary-size(20)>> ->
        try do
          <<h::size(16), old_size::size(16), payload::binary>> = message
          new_size = old_size - 24
          {true, <<h::size(16), new_size::size(16), payload::binary>>}
        rescue
           _ ->
             Logger.info ":integrity invalid in BiDS message."
             raise IntegrityError, message: "Integrity check failed"
        end
      _ ->
        Logger.info "No :integrity was found in BiDS message."
        {false, bids_binary}
    end
  end

  # full check of integrity
  def check_integrity(bids_binary, nil) do
    Logger.info "Nil :integrity was found in BiDS message."
    {false, bids_binary}
  end
  def check_integrity(bids_binary, key) do
    s = byte_size(bids_binary) - 24
    case bids_binary do
      <<message::binary-size(s), 0x00::size(8), 0x08::size(8), 0x00::size(8), 0x14::size(8), fingerprint::binary-size(20)>> ->
        try do
          ^fingerprint = hmac_sha1(message, key)
          <<h::size(16), old_size::size(16), payload::binary>> = message
          new_size = old_size - 24
          {true, <<h::size(16), new_size::size(16), payload::binary>>}
        rescue
           _ ->
             Logger.info ":integrity invalid in BiDS message."
             raise IntegrityError, message: "Integrity check failed"
        end
      _ ->
        Logger.info "No :integrity was found in BiDS message."
        {false, bids_binary}
    end
  end

  @doc """
  Inserts a valid integrity marker and value to the end of a BiDS binary (RFC 3489)
  """
  def insert_integrity(bids_binary, nil) do
    bids_binary
  end

  def insert_integrity(bids_binary, key) do
    Logger.info "INSERTING :integrity WITH KEY #{inspect key}"
    <<0::2, type::14, len::16, magic::32, trid::96, attrs::binary>> = bids_binary
    nlen = len + 4 + 20 ## 24 is the length of Message-Integrity attribute
    value = <<0::2, type::14, nlen::16, magic::32, trid::96, attrs::binary>>
    integrity = hmac_sha1(value, key)
    <<0::2, type::14, nlen::16, magic::32, trid::96, attrs::binary, 0x00::size(8), 0x08::size(8), 0x00::size(8), 0x14::size(8), integrity::binary-size(20)>>
  end

  def hmac_sha1(msg, hash) when is_binary(msg) and is_binary(hash) do
    key = :crypto.hash(:md5, to_char_list(hash))
    :crypto.sha_mac(key, msg)
  end

  @doc """
  Removes null value from the end of a list string
  """
  def fix_null_terminated(str) when is_list(str) do
    # FIXME should we print \0 anyway?
  # [ case X of 0 -> "\\0"; _ -> X end || X <- String ].
    for x <- str, x != 0, do: x 
  end
    @doc """
  Removes null value from the end of a bitstring
  """
  def fix_null_terminated(bin) when is_binary(bin) do
    for <<x::8 <- bin>>, x != 0, do: <<x::size(8)>>, into: ""
  end
end