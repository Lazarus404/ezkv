defmodule EZ.REST.Index do
  @moduledoc """
  Simple RESTful interface for keys
  """
  use Ewebmachine
  import EZ.REST.Index.Impl
  import EZ.REST.Utils

  resource ['kv', :bucket, :key] do
    allowed_methods do: [:GET, :POST, :PUT, :DELETE, :HEAD, :OPTIONS]
    content_types_provided do: [{'application/json',:to_json}]
    content_types_accepted do: [{'application/json',:from_json}, {'text/javascript',:from_json}]
    post_is_create do: true
    create_path do: 'kv'
    options do: std_options
    
    @doc """
    Submission
    """
    from_json do
      {p, r, c} = create_key(:wrq.path_info(:bucket,_req), :wrq.path_info(:key,_req), _req, _ctx)
      {true, :wrq.set_resp_body(p, r), c}
    end

    @doc """
    Extraction
    """
    to_json do
      get_key(:wrq.path_info(:bucket,_req), :wrq.path_info(:key,_req), _req, _ctx)
    end

    @doc """
    Deletion
    """
    delete_resource do
      {p, r, c} = delete_key(:wrq.path_info(:bucket,_req), :wrq.path_info(:key,_req), _req, _ctx)
      {true, :wrq.set_resp_body(p, r), c}
    end
  end
end