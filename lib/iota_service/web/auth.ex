defmodule IotaService.Web.Auth do
  @moduledoc """
  JWT token generation and verification for the IOTA Service API.

  Uses Joken with HS256 signing.  Tokens carry the user id, email,
  and a standard `exp` claim.

  ## Configuration

      config :iota_service, IotaService.Web.Auth,
        secret: "change-me-in-production",
        token_ttl_seconds: 3600,
        users: [
          %{id: "usr_dev", email: "dev@iota.local", password: "iota_dev_2026"}
        ]
  """

  use Joken.Config

  @impl true
  def token_config do
    default_claims(default_exp: ttl_seconds())
  end

  # --- Public API -----------------------------------------------------------

  @doc """
  Authenticate a user by email and password.

  Returns `{:ok, user}` on success or `{:error, :invalid_credentials}`.
  """
  @spec authenticate(String.t(), String.t()) :: {:ok, map()} | {:error, :invalid_credentials}
  def authenticate(email, password) do
    users()
    |> Enum.find(fn u -> u.email == email and u.password == password end)
    |> case do
      nil -> {:error, :invalid_credentials}
      user -> {:ok, Map.take(user, [:id, :email])}
    end
  end

  @doc """
  Generate a signed JWT for the given user.

  Returns `{:ok, token, claims}`.
  """
  @spec generate_token(map()) :: {:ok, String.t(), map()} | {:error, term()}
  def generate_token(%{id: user_id, email: email}) do
    extra_claims = %{"user_id" => user_id, "email" => email}

    case generate_and_sign(extra_claims, signer()) do
      {:ok, token, claims} -> {:ok, token, claims}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Verify a JWT token and return its claims.

  Returns `{:ok, claims}` or `{:error, reason}`.
  """
  @spec verify_token(String.t()) :: {:ok, map()} | {:error, term()}
  def verify_token(token) when is_binary(token) do
    case verify_and_validate(token, signer()) do
      {:ok, claims} -> {:ok, claims}
      {:error, reason} -> {:error, reason}
    end
  end

  # --- Private --------------------------------------------------------------

  defp signer do
    Joken.Signer.create("HS256", secret())
  end

  defp secret do
    config()[:secret] || raise "JWT secret not configured"
  end

  defp ttl_seconds do
    config()[:token_ttl_seconds] || 3600
  end

  defp users do
    raw = config()[:users] || []

    Enum.map(raw, fn
      %{} = m -> m
      m when is_list(m) -> Map.new(m, fn {k, v} -> {k, v} end)
    end)
  end

  defp config do
    Application.get_env(:iota_service, __MODULE__, [])
  end
end
