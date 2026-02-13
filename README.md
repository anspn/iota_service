# IotaService

Elixir application for IOTA Tangle operations, including DID (Decentralized Identifier)
management and data notarization.

## Features

- **DID Generation**: Create IOTA DIDs with Ed25519 verification methods
- **Notarization**: Timestamp and hash-anchor data for Tangle submission
- **Supervised Architecture**: Fault-tolerant supervision tree
- **NIF Integration**: Uses Rust NIFs for cryptographic operations


## Quick Start

```elixir
# Start the application
Application.ensure_all_started(:iota_service)

# Generate a DID
{:ok, did_result} = IotaService.generate_did()
IO.puts("Generated DID: #{did_result.did}")

# Notarize data
{:ok, payload} = IotaService.notarize("Important document content")
IO.inspect(payload, label: "Notarization payload")

# Verify the DID format
true = IotaService.valid_did?(did_result.did)
```

## Supervision Tree

```
IotaService.Application (rest_for_one)
├── IotaService.NIF.Loader           # Ensures NIF is loaded
├── IotaService.Identity.Supervisor  # (one_for_one)
│   ├── IotaService.Identity.Cache   # ETS-backed DID cache
│   └── IotaService.Identity.Server  # DID operations
└── IotaService.Notarization.Supervisor  # (one_for_one)
    ├── IotaService.Notarization.Queue   # Job queue
    └── IotaService.Notarization.Server  # Notarization operations
```

## API Reference

### Identity

```elixir
# Generate DID for different networks
IotaService.generate_did()                    # IOTA mainnet
IotaService.generate_did(network: :smr)       # Shimmer
IotaService.generate_did(network: :rms)       # Shimmer testnet
IotaService.generate_did(network: :atoi)      # IOTA testnet

# Validate DID format
IotaService.valid_did?("did:iota:0x123...")   # => true/false

# Create DID URL
IotaService.create_did_url("did:iota:0x123", "key-1")
# => {:ok, "did:iota:0x123#key-1"}
```

### Notarization

```elixir
# Hash data
hash = IotaService.hash("data to hash")

# Create notarization payload
{:ok, payload} = IotaService.notarize("document", "my-tag")

# Verify payload
{:ok, result} = IotaService.verify_notarization(payload["payload_hex"])
```

### Queue (Batch Processing)

```elixir
# Enqueue for later processing
{:ok, job_ref} = IotaService.enqueue_notarization("data", "batch-tag")

# Check stats
IotaService.queue_stats()
# => %{pending: 1, total_jobs: 1, processed: 0, failed: 0}
```

## Configuration

Configure via `config/config.exs`

## Testing

Test against local node with:

```bash
# Unit tests only (no node needed)
mix test

# All local + ledger tests
IOTA_TEST_SECRET_KEY=iotaprivkey1... \
IOTA_IDENTITY_PKG_ID=0xa1fb... \
MIX_ENV=local mix test
```

## License

MIT
