# Exclude :testnet tagged tests unless MIX_ENV=local (for backward compat) or
# the IOTA_TESTNET env var is set. This allows running integration tests against
# the IOTA testnet without needing a local node.
exclude =
  cond do
    Mix.env() == :local -> []
    System.get_env("IOTA_TESTNET") == "1" -> []
    true -> [:testnet]
  end

ExUnit.start(exclude: exclude)
