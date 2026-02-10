import Config

config :iota_service, :faucet_url, "https://faucet.testnet.iota.cafe/gas"

import_config "#{Mix.env()}.exs"
