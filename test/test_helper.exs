# Exclude :local and :ledger tagged tests unless MIX_ENV=local
exclude = if Mix.env() == :local, do: [], else: [:local, :ledger]

ExUnit.start(exclude: exclude)
