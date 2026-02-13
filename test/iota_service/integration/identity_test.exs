defmodule IotaService.Integration.IdentityTest do
  @moduledoc """
  Integration tests for the Identity (DID) lifecycle against a local IOTA node.

  Run with: MIX_ENV=local mix test test/iota_service/integration/identity_test.exs
  """

  use ExUnit.Case

  @moduletag :local

  describe "DID generation" do
    test "generates a DID with default network (iota)" do
      assert {:ok, result} = IotaService.generate_did()

      assert is_binary(result.did)
      assert String.starts_with?(result.did, "did:iota:0x")
      # document comes as a JSON string from the NIF; verify it's valid JSON
      assert is_binary(result.document)
      assert {:ok, _doc} = Jason.decode(result.document)
      assert is_binary(result.verification_method_fragment)
      assert result.network == :iota
      assert %DateTime{} = result.generated_at
    end

    test "generates a DID for each supported network" do
      networks = [:iota, :smr, :rms, :atoi]

      for network <- networks do
        assert {:ok, result} = IotaService.generate_did(network: network),
               "Failed to generate DID for network #{network}"

        assert result.network == network

        expected_prefix =
          case network do
            :iota -> "did:iota:0x"
            other -> "did:iota:#{other}:0x"
          end

        assert String.starts_with?(result.did, expected_prefix),
               "DID #{result.did} does not start with #{expected_prefix}"
      end
    end

    test "rejects invalid network" do
      assert {:error, {:invalid_network, :invalid}} =
               IotaService.generate_did(network: :invalid)
    end
  end

  describe "DID validation" do
    test "validates a correctly generated DID" do
      {:ok, result} = IotaService.generate_did()
      assert IotaService.valid_did?(result.did)
    end

    test "rejects invalid DID formats" do
      refute IotaService.valid_did?("")
      refute IotaService.valid_did?("not-a-did")
      refute IotaService.valid_did?("did:other:0x123")
    end
  end

  describe "DID URL creation" do
    test "creates a DID URL with a fragment" do
      {:ok, result} = IotaService.generate_did()
      assert {:ok, url} = IotaService.create_did_url(result.did, "key-1")
      assert url == "#{result.did}#key-1"
    end

    test "creates DID URLs with various fragments" do
      {:ok, result} = IotaService.generate_did()

      fragments = ["key-1", "auth-0", "verification", "my-service"]

      for fragment <- fragments do
        assert {:ok, url} = IotaService.create_did_url(result.did, fragment)
        assert String.ends_with?(url, "##{fragment}")
      end
    end
  end

  describe "DID caching" do
    test "caches DID on generation and retrieves it" do
      {:ok, result} = IotaService.generate_did()

      assert {:ok, cached} = IotaService.get_cached_did(result.did)
      assert cached.did == result.did
      assert cached.document == result.document
    end

    test "returns :miss for unknown DID" do
      assert :miss = IotaService.get_cached_did("did:iota:0xunknown")
    end

    test "skips caching when cache: false" do
      # Clear cache first to avoid hits from prior tests with the same DID
      IotaService.Identity.Cache.clear()

      {:ok, result} = IotaService.generate_did(cache: false)

      assert :miss = IotaService.get_cached_did(result.did)
    end
  end

  describe "full DID lifecycle" do
    test "generate → validate → create URL → cache lookup" do
      # Step 1: Generate
      assert {:ok, did_result} = IotaService.generate_did()
      did = did_result.did

      # Step 2: Validate
      assert IotaService.valid_did?(did)

      # Step 3: Create DID URL
      assert {:ok, url} = IotaService.create_did_url(did, "key-1")
      assert url == "#{did}#key-1"

      # Step 4: Retrieve from cache
      assert {:ok, cached} = IotaService.get_cached_did(did)
      assert cached.did == did
      assert cached.network == :iota
    end
  end
end
