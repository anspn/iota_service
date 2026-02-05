defmodule IotaService do
  @moduledoc """
  IOTA Service - Elixir interface for IOTA Tangle operations.

  This module provides a high-level API for:
  - **Identity**: DID (Decentralized Identifier) generation and management
  - **Notarization**: Data anchoring on the IOTA Tangle

  ## Quick Start

      # Generate a new DID
      {:ok, did_result} = IotaService.generate_did()

      # Notarize data
      {:ok, payload} = IotaService.notarize("Hello, IOTA!")

  ## Architecture

  The service is built on a supervision tree:

  ```
  IotaService.Application (rest_for_one)
  ├── NIF.Loader           - Ensures Rust NIF is loaded
  ├── Identity.Supervisor  - DID services
  │   ├── Identity.Cache   - ETS cache for DIDs
  │   └── Identity.Server  - DID operations
  └── Notarization.Supervisor
      ├── Notarization.Queue  - Job queue
      └── Notarization.Server - Notarization operations
  ```
  """

  alias IotaService.Identity
  alias IotaService.Notarization

  # ============================================================================
  # Identity API
  # ============================================================================

  @doc """
  Generate a new IOTA DID.

  ## Options
  - `:network` - Target network: `:iota`, `:smr`, `:rms`, `:atoi` (default: `:iota`)

  ## Examples

      iex> {:ok, result} = IotaService.generate_did()
      iex> String.starts_with?(result.did, "did:iota:0x")
      true

      iex> {:ok, result} = IotaService.generate_did(network: :smr)
      iex> String.starts_with?(result.did, "did:iota:smr:0x")
      true
  """
  @spec generate_did(keyword()) :: {:ok, map()} | {:error, term()}
  defdelegate generate_did(opts \\ []), to: Identity.Server

  @doc """
  Check if a string is a valid IOTA DID format.

  ## Examples

      iex> IotaService.valid_did?("did:iota:0x123")
      true

      iex> IotaService.valid_did?("not-a-did")
      false
  """
  @spec valid_did?(String.t()) :: boolean()
  defdelegate valid_did?(did), to: Identity.Server

  @doc """
  Create a DID URL with a fragment.

  ## Examples

      iex> IotaService.create_did_url("did:iota:0x123", "key-1")
      {:ok, "did:iota:0x123#key-1"}
  """
  @spec create_did_url(String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  defdelegate create_did_url(did, fragment), to: Identity.Server

  @doc """
  Get a cached DID document.
  """
  @spec get_cached_did(String.t()) :: {:ok, map()} | :miss
  defdelegate get_cached_did(did), to: Identity.Cache, as: :get

  # ============================================================================
  # Notarization API
  # ============================================================================

  @doc """
  Notarize data on the IOTA Tangle.

  Creates a timestamped, hash-anchored payload ready for Tangle submission.

  ## Parameters
  - `data` - Binary data to notarize
  - `tag` - Optional tag/label (default: "iota_service")

  ## Examples

      iex> {:ok, payload} = IotaService.notarize("test")
      iex> is_binary(payload["data_hash"]) and String.length(payload["data_hash"]) == 64
      true
  """
  @spec notarize(binary(), String.t()) :: {:ok, map()} | {:error, term()}
  defdelegate notarize(data, tag \\ "iota_service"), to: Notarization.Server, as: :create_payload

  @doc """
  Hash data using SHA-256.

  ## Examples

      iex> IotaService.hash("hello")
      "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
  """
  @spec hash(binary()) :: String.t()
  defdelegate hash(data), to: Notarization.Server, as: :hash_data

  @doc """
  Verify a notarization payload.
  """
  @spec verify_notarization(String.t()) :: {:ok, map()} | {:error, term()}
  defdelegate verify_notarization(payload_hex), to: Notarization.Server, as: :verify_payload

  # ============================================================================
  # Queue API
  # ============================================================================

  @doc """
  Enqueue data for batch notarization.
  """
  @spec enqueue_notarization(binary(), String.t()) :: {:ok, reference()} | {:error, :queue_full}
  defdelegate enqueue_notarization(data, tag \\ "iota_service"), to: Notarization.Queue, as: :enqueue

  @doc """
  Get notarization queue statistics.
  """
  @spec queue_stats() :: map()
  defdelegate queue_stats(), to: Notarization.Queue, as: :stats

  # ============================================================================
  # Health & Status
  # ============================================================================

  @doc """
  Check if the IOTA NIF is loaded and ready.
  """
  @spec nif_ready?() :: boolean()
  defdelegate nif_ready?(), to: IotaService.NIF.Loader, as: :ready?

  @doc """
  Get NIF information.
  """
  @spec nif_info() :: map()
  defdelegate nif_info(), to: IotaService.NIF.Loader, as: :info
end
