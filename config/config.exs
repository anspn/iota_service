import Config

# IOTA Service base configuration
config :iota_service,
  faucet_url: "https://faucet.testnet.iota.cafe/gas",
  # IOTA Rebased node URL
  node_url: "http://127.0.0.1:9000",
  # Identity Move package ObjectID ("" for auto-discovery on official networks)
  identity_pkg_id: "",
  # Notarization Move package ObjectID ("" for auto-discovery on official networks)
  notarize_pkg_id: "",
  # Web server
  port: 4000,
  start_web: true,
  # Set to true to require login before accessing the app
  login_required: true

# JWT Authentication
config :iota_service, IotaService.Web.Auth,
  secret: "dev-secret-please-change-in-production",
  token_ttl_seconds: 3600,
  users: [
    %{id: "usr_admin", email: "admin@iota.local", password: "iota_admin_2026", role: "admin"},
    %{id: "usr_user", email: "user@iota.local", password: "iota_user_2026", role: "user"}
  ]

# Joken default signer (not used — we configure our own in Web.Auth)
config :joken, default_signer: nil

import_config "#{Mix.env()}.exs"
