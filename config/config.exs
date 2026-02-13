import Config

# IOTA Service base configuration
config :iota_service,
  faucet_url: "https://faucet.testnet.iota.cafe/gas",
  # IOTA Rebased node URL
  node_url: "http://127.0.0.1:9000",
  # Identity Move package ObjectID ("" for auto-discovery on official networks)
  identity_pkg_id: "",
  # Notarization Move package ObjectID ("" for auto-discovery on official networks)
  notarize_pkg_id: ""

import_config "#{Mix.env()}.exs"
