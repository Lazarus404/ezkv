defmodule EZ.REST.Utils do
  @codes %{
    ok: {200, 'OK'},
    created: {201, 'Created'},
    accepted: {202, 'Accepted'},
    multiple: {300, 'Multiple Choices'},
    bad_request: {400, 'Bad Request'},
    unauthorized: {401, 'Unauthorized'},
    forbidden: {403, 'Forbidden'},
    not_found: {404, 'Not Found'},
    not_allowed: {405, 'Method Not Allowed'},
    error: {500, 'Server Error'}
  }

  def parse_params(req) do
    case :mochiweb_util.parse_qs(:wrq.req_body(req)) ++ :wrq.req_qs(req) do
      [{json, []}] when is_list(json) ->
        Poison.decode!(to_string(json))
      p -> 
        Enum.into(Enum.map(p, fn({k, v}) -> {to_string(k), to_string(v)} end), %{})
    end
  end

  def resp req,ctx,data do
    {nreq, msg} = respond(req, :ok, data)
    {msg, nreq, ctx}
  end

  def err req,ctx,status do
    {nreq, code} = error(req, status)
    {{:halt, code}, nreq, ctx}
  end

  def respond(req, status, data) do
    req
     |> set_code(status)
     |> open_origin
     |> resp_encode(get_code_num(status), data, nil)
  end

  
  def response_body(req, status, data) do
    {nreq, msg} = req
     |> set_code(status)
     |> open_origin
     |> resp_encode(get_code_num(status), data, nil)
    :wrq.set_resp_body(msg, nreq)
  end

  
  def error(req, status) do
    req
     |> set_code(status)
     |> open_origin
     |> err_encode(get_code_num(status))
  end

  
  def error_body(req, status, err) do
    {nreq, msg} = req
     |> set_code(status)
     |> open_origin
     |> resp_encode(get_code_num(status), nil, err)
    :wrq.set_resp_body(msg, nreq)
  end

  
  def resp_encode(req, status, data, err) do
    {req, Poison.encode!(data)}
  end

  def err_encode(req, status_code) do
    {req, status_code}
  end


  def open_origin(req), do: :wrq.set_resp_headers(std_options(), req)  

  
  def get_code(status) do
    case Dict.fetch(@codes, status) do
      {:ok, code} -> code
      :error -> {500, :server_error}
    end
  end


  def get_code_num(status) do
    {num, _} = get_code(status)
    num
  end


  def set_code(req, status), do: :wrq.set_response_code(get_code(status), req)


  def std_options() do
    [
      {'Access-Control-Allow-Origin', '*'},
      {'Access-Control-Allow-Methods', 'POST, GET, PUT, DELETE, HEAD, OPTIONS'},
      {'Access-Control-Max-Age', 86400},
      {'Access-Control-Allow-Headers', 'X-Requested-With, Content-Type, Accept, Method'},
      {'Content-Type', 'application/json'}
    ]
  end
end