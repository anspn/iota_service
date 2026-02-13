defmodule IotaService.Web.API.IdentityHandler do
  @moduledoc """
  DID / Identity API handler.

  All routes require JWT authentication (via `Authenticate` plug).

  ## Endpoints

  - `POST   /api/dids`             — Create (generate or publish) a DID
  - `GET    /api/dids/:did`        — Resolve / look up a DID
  - `POST   /api/dids/:did/revoke` — Revoke a DID
  """

  use Plug.Router

  alias IotaService.Web.API.Helpers
  alias IotaService.Web.Plugs.Authenticate

  # Require Bearer token on all identity routes
  plug Authenticate
  plug :match
  plug :dispatch

  # ---------------------------------------------------------------------------
  # POST /api/dids — Create a new DID
  # ---------------------------------------------------------------------------
  post "/" do
    params = conn.body_params || %{}
    publish = params["publish"] == true

    result =
      if publish do
        create_published_did(params)
      else
        network = parse_network(params["network"])
        create_local_did(network)
      end

    case result do
      {:ok, response} ->
        Helpers.json(conn, 201, response)

      {:error, {:invalid_network, _} = reason} ->
        Helpers.json(conn, 400, %{
          error: "invalid_request",
          message: "Invalid network: #{inspect(reason)}"
        })

      {:error, {:missing_option, key}} ->
        Helpers.json(conn, 400, %{
          error: "missing_parameter",
          message: "Required parameter missing: #{key}"
        })

      {:error, reason} when is_binary(reason) ->
        Helpers.json(conn, 422, %{error: "publish_failed", message: reason})

      {:error, reason} ->
        Helpers.json(conn, 500, %{
          error: "internal_error",
          message: "DID creation failed: #{inspect(reason)}"
        })
    end
  end

  # ---------------------------------------------------------------------------
  # GET /api/dids/:did — Resolve a DID (cache → ledger fallback)
  # ---------------------------------------------------------------------------
  get "/:did" do
    did = URI.decode(did)
    params = Plug.Conn.fetch_query_params(conn).query_params

    unless IotaService.valid_did?(did) do
      Helpers.json(conn, 400, %{error: "invalid_request", message: "Invalid DID format"})
    else
      case resolve_did(did, params) do
        {:ok, response} ->
          Helpers.json(conn, 200, response)

        {:error, reason} when is_binary(reason) ->
          Helpers.json(conn, 404, %{error: "not_found", message: reason})

        {:error, reason} ->
          Helpers.json(conn, 404, %{
            error: "not_found",
            message: "Could not resolve DID: #{inspect(reason)}"
          })
      end
    end
  end

  # ---------------------------------------------------------------------------
  # POST /api/dids/:did/revoke — Revoke a DID
  # ---------------------------------------------------------------------------
  post "/:did/revoke" do
    did = URI.decode(did)
    params = conn.body_params || %{}
    reason = params["reason"]

    unless IotaService.valid_did?(did) do
      Helpers.json(conn, 400, %{error: "invalid_request", message: "Invalid DID format"})
    else
      case revoke_did(did, reason) do
        {:ok, response} ->
          Helpers.json(conn, 200, response)

        {:error, :not_found} ->
          Helpers.json(conn, 404, %{
            error: "not_found",
            message: "DID not found or does not belong to this user"
          })

        {:error, :already_revoked} ->
          Helpers.json(conn, 409, %{
            error: "already_revoked",
            message: "This DID has already been revoked"
          })
      end
    end
  end

  match _ do
    Helpers.json(conn, 404, %{error: "not_found", message: "Identity route not found"})
  end

  # ===========================================================================
  # Private
  # ===========================================================================

  defp parse_network(nil), do: :iota
  defp parse_network(n) when n in ["iota", "smr", "rms", "atoi"], do: String.to_atom(n)
  defp parse_network(n) when is_atom(n), do: n
  defp parse_network(n), do: {:invalid, n}

  defp create_local_did(network) do
    case IotaService.generate_did(network: network) do
      {:ok, did_result} ->
        {:ok, format_did_response(did_result, nil, "active")}

      error ->
        error
    end
  end

  defp create_published_did(params) do
    secret_key = params["secret_key"]

    unless secret_key && secret_key != "" do
      {:error, {:missing_option, :secret_key}}
    else
      opts =
        [secret_key: secret_key]
        |> maybe_put(:node_url, params["node_url"])
        |> maybe_put(:identity_pkg_id, params["identity_pkg_id"])
        # Fall back to Application env if client didn't supply
        |> maybe_put(:node_url, Application.get_env(:iota_service, :node_url))
        |> maybe_put(:identity_pkg_id, Application.get_env(:iota_service, :identity_pkg_id))

      case IotaService.publish_did(opts) do
        {:ok, did_result} ->
          {:ok, format_did_response(did_result, nil, "active")}

        error ->
          error
      end
    end
  end

  defp resolve_did(did, params) do
    # Try cache first, then ledger
    case IotaService.get_cached_did(did) do
      {:ok, cached} ->
        status = Map.get(cached, :status, "active")
        {:ok, format_did_response(cached, Map.get(cached, :label), status)}

      :miss ->
        resolve_from_ledger(did, params)
    end
  end

  defp resolve_from_ledger(did, params) do
    opts =
      []
      |> maybe_put(:node_url, params["node_url"])
      |> maybe_put(:identity_pkg_id, params["identity_pkg_id"])
      # Fall back to Application env if client didn't supply
      |> maybe_put(:node_url, Application.get_env(:iota_service, :node_url))
      |> maybe_put(:identity_pkg_id, Application.get_env(:iota_service, :identity_pkg_id))

    case IotaService.resolve_did(did, opts) do
      {:ok, resolved} ->
        {:ok, %{
          did: resolved["did"],
          network: resolved["network"],
          document: resolved["document"],
          status: "active"
        }}

      error ->
        error
    end
  end

  defp revoke_did(did, reason) do
    case IotaService.get_cached_did(did) do
      {:ok, cached} ->
        if Map.get(cached, :status) == "revoked" do
          {:error, :already_revoked}
        else
          # Mark as revoked in cache
          revoked = Map.merge(cached, %{status: "revoked", revoked_at: DateTime.utc_now(), revoke_reason: reason})
          IotaService.Identity.Cache.put(did, revoked)

          {:ok, %{
            did: did,
            status: "revoked",
            revoked_at: DateTime.to_iso8601(revoked.revoked_at),
            reason: reason
          }}
        end

      :miss ->
        {:error, :not_found}
    end
  end

  defp format_did_response(did_result, label, status) do
    doc =
      case Map.get(did_result, :document) do
        nil -> nil
        doc when is_binary(doc) -> try_decode_json(doc)
        doc -> doc
      end

    %{
      did: did_result.did,
      network: to_string(Map.get(did_result, :network, "iota")),
      label: label,
      created_at: Map.get(did_result, :published_at, Map.get(did_result, :generated_at, DateTime.utc_now())) |> DateTime.to_iso8601(),
      status: status,
      document: doc
    }
  end

  defp try_decode_json(str) do
    case Jason.decode(str) do
      {:ok, decoded} -> decoded
      _ -> str
    end
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, ""), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
