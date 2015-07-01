defmodule EZ.REST.Index.Impl do
  @moduledoc """
  implementation for RESTful interface
  """
  require Logger
  import EZ.REST.Utils
  alias EZ.Queue.Manager, as: Queue

  def create_key(bucket, key, req, ctx) do
    body = :wrq.req_body(req)
    case body do
      "" -> resp(req,ctx,"no body provided")
      r ->
        case Poison.decode(body) do
          {:ok, json} ->
            case json do
              val when is_integer(val) ->
                Queue.do_execute(:set, [key, {:int, val}], to_string(bucket))
              other ->
                Queue.do_execute(:set, [key, {:json, other}], to_string(bucket))
            end
          _ ->
            Queue.do_execute(:set, [key, {:string, body}], to_string(bucket))
        end
        resp(req,ctx,"ok")
    end
  end

  def get_key(bucket, key, req, ctx) do
    case Queue.do_execute(:get, key, to_string(bucket)) do
      {:ok, val} ->
        r = case val do
          {:json, json} -> Poison.encode!(json)
          {:string, str} -> str
          {:int, int} -> "#{int}"
        end
        resp(req,ctx,r)
      {:error, _reason} ->
        err(req, ctx, :not_found)
    end
  end

  def delete_key(bucket, key, req, ctx) do
    {:ok, val} = Queue.do_execute(:del, key, to_string(bucket))
    resp(req,ctx,"ok")
  end
end