defmodule IotaService.Web.Frontend.Router do
  @moduledoc """
  Server-side rendered frontend router.

  Serves HTML pages that provide a playground UI for interacting with
  the IOTA Service REST API.
  """

  use Plug.Router

  alias IotaService.Web.Frontend.Templates

  plug :match
  plug :dispatch

  get "/" do
    nif_info = IotaService.nif_info()
    cache_stats = IotaService.Identity.Cache.stats()
    queue_stats = IotaService.queue_stats()

    html = Templates.render(:home, %{
      nif_info: nif_info,
      cache_stats: cache_stats,
      queue_stats: queue_stats
    })

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  get "/login" do
    html = Templates.render(:login, %{})

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  get "/identity" do
    html = Templates.render(:identity, %{})

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  # Catch-all: redirect unknown frontend routes to home
  match _ do
    conn
    |> put_resp_header("location", "/")
    |> send_resp(302, "")
  end
end
