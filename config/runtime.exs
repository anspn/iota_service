import Config

# Runtime configuration — loaded at application startup (not compile time).
# This is the right place to read environment variables for Docker/production.

if config_env() == :prod do
  # --- IOTA Node ---
  config :iota_service,
    node_url: System.get_env("IOTA_NODE_URL") || "http://127.0.0.1:9000",
    faucet_url: System.get_env("IOTA_FAUCET_URL") || "https://faucet.testnet.iota.cafe/gas",
    identity_pkg_id: System.get_env("IOTA_IDENTITY_PKG_ID") || "",
    notarize_pkg_id: System.get_env("IOTA_NOTARIZE_PKG_ID") || ""

  # --- Web server ---
  port =
    case System.get_env("PORT") do
      nil -> 4000
      val -> String.to_integer(val)
    end

  config :iota_service, port: port

  # --- JWT Auth ---
  secret =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      Environment variable SECRET_KEY_BASE is missing.
      Generate one with: mix phx.gen.secret (or openssl rand -base64 64)
      """

  config :iota_service, IotaService.Web.Auth,
    secret: secret,
    token_ttl_seconds:
      String.to_integer(System.get_env("TOKEN_TTL_SECONDS") || "3600"),
    users: [
      %{
        id: System.get_env("ADMIN_USER_ID") || "usr_admin",
        email: System.get_env("ADMIN_EMAIL") || "admin@iota.local",
        password:
          System.get_env("ADMIN_PASSWORD") ||
            raise("Environment variable ADMIN_PASSWORD is missing."),
        role: "admin"
      }
    ]
end
