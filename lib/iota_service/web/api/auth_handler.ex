defmodule IotaService.Web.API.AuthHandler do
  @moduledoc """
  Authentication API handler.

  ## Endpoints

  - `POST /api/auth/login` — Authenticate with email/password, receive JWT
  """

  use Plug.Router

  alias IotaService.Web.API.Helpers
  alias IotaService.Web.Auth

  plug :match
  plug :dispatch

  # POST /api/auth/login
  post "/login" do
    with {:ok, %{"email" => email, "password" => password}} <-
           Helpers.require_fields(conn.body_params, ["email", "password"]),
         {:ok, user} <- Auth.authenticate(email, password),
         {:ok, token, claims} <- Auth.generate_token(user) do
      Helpers.json(conn, 200, %{
        token: token,
        expires_at: format_exp(claims["exp"]),
        user: %{id: user.id, email: user.email, role: user.role}
      })
    else
      {:error, [:password]} ->
        Helpers.validation_error(conn, "Password is required")

      {:error, missing} when is_list(missing) ->
        Helpers.validation_error(conn, "Missing required fields: #{Enum.join(missing, ", ")}")

      {:error, :invalid_credentials} ->
        Helpers.json(conn, 401, %{
          error: "invalid_credentials",
          message: "Email or password is incorrect"
        })

      {:error, reason} ->
        Helpers.json(conn, 500, %{
          error: "internal_error",
          message: "Authentication failed: #{inspect(reason)}"
        })
    end
  end

  match _ do
    Helpers.json(conn, 404, %{error: "not_found", message: "Auth route not found"})
  end

  # -- Helpers ---------------------------------------------------------------

  defp format_exp(nil), do: nil

  defp format_exp(exp) when is_integer(exp) do
    exp |> DateTime.from_unix!() |> DateTime.to_iso8601()
  end
end
