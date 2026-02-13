defmodule IotaService.Web.Frontend.Router do
  @moduledoc """
  Server-side rendered frontend router.

  Serves HTML pages that provide a playground UI for interacting with
  the IOTA Service REST API.

  The `login_required` config flag is passed to the layout so the
  client-side JS can redirect to `/login` when no session token
  is present.
  """

  use Plug.Router

  alias IotaService.Web.Frontend.Templates

  plug :match
  plug :dispatch

  # --- Root / Dashboard ---------------------------------------------------
  get "/" do
    nif_info = IotaService.nif_info()
    cache_stats = IotaService.Identity.Cache.stats()
    queue_stats = IotaService.queue_stats()

    html = Templates.render(:dashboard, %{
      nif_info: nif_info,
      cache_stats: cache_stats,
      queue_stats: queue_stats,
      login_required: login_required?()
    })

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  # --- Login --------------------------------------------------------------
  get "/login" do
    html = Templates.render(:login, %{})

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  # --- Identity -----------------------------------------------------------
  get "/identity" do
    html = Templates.render(:identity, %{
      login_required: login_required?()
    })

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  # Catch-all: redirect unknown frontend routes to /
  match _ do
    conn
    |> put_resp_header("location", "/")
    |> send_resp(302, "")
  end

  defp login_required? do
    Application.get_env(:iota_service, :login_required, true)
  end
end
