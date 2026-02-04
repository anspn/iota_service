defmodule IotaService.Notarization.Server do
  @moduledoc """
  GenServer for data notarization operations.

  Handles hashing, payload creation, and verification
  for anchoring data on the IOTA Tangle.
  """

  use GenServer

  require Logger

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Hash data using SHA-256.

  ## Parameters
  - `data` - Binary data to hash

  ## Returns
  - Hex-encoded SHA-256 hash string
  """
  @spec hash_data(binary()) :: String.t()
  def hash_data(data) when is_binary(data) do
    GenServer.call(__MODULE__, {:hash_data, data})
  end

  @doc """
  Create a notarization payload for anchoring on IOTA Tangle.

  ## Parameters
  - `data` - Binary data to notarize
  - `tag` - Tag/label for the notarization (optional)

  ## Returns
  - `{:ok, payload}` - Payload ready for submission
  - `{:error, reason}` - Creation failed
  """
  @spec create_payload(binary(), String.t()) :: {:ok, map()} | {:error, term()}
  def create_payload(data, tag \\ "iota_service") when is_binary(data) and is_binary(tag) do
    GenServer.call(__MODULE__, {:create_payload, data, tag})
  end

  @doc """
  Verify a notarization payload.

  ## Parameters
  - `payload_hex` - Hex-encoded payload to verify

  ## Returns
  - `{:ok, verification_result}` - Verification details
  - `{:error, reason}` - Verification failed
  """
  @spec verify_payload(String.t()) :: {:ok, map()} | {:error, term()}
  def verify_payload(payload_hex) when is_binary(payload_hex) do
    GenServer.call(__MODULE__, {:verify_payload, payload_hex})
  end

  @doc """
  Check if a string is valid hexadecimal.
  """
  @spec valid_hex?(String.t()) :: boolean()
  def valid_hex?(input) when is_binary(input) do
    GenServer.call(__MODULE__, {:valid_hex?, input})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Notarization Server started")

    state = %{
      notarizations_created: 0,
      verifications_performed: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:hash_data, data}, _from, state) do
    result = call_nif(:hash_data, [data])
    {:reply, result, state}
  end

  @impl true
  def handle_call({:create_payload, data, tag}, _from, state) do
    start_time = System.monotonic_time()

    result =
      with hash when is_binary(hash) <- call_nif(:hash_data, [data]),
           {:ok, payload_json} <- call_nif(:create_notarization_payload, [hash, tag]),
           {:ok, payload} <- Jason.decode(payload_json) do
        emit_telemetry(:create_payload, start_time, %{success: true})
        {:ok, payload}
      else
        {:error, _} = error ->
          emit_telemetry(:create_payload, start_time, %{success: false})
          error
      end

    new_state =
      case result do
        {:ok, _} -> %{state | notarizations_created: state.notarizations_created + 1}
        _ -> state
      end

    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:verify_payload, payload_hex}, _from, state) do
    start_time = System.monotonic_time()

    result =
      with {:ok, json} <- call_nif(:verify_notarization_payload, [payload_hex]),
           {:ok, verification} <- Jason.decode(json) do
        emit_telemetry(:verify_payload, start_time, %{success: true})
        {:ok, verification}
      else
        {:error, _} = error ->
          emit_telemetry(:verify_payload, start_time, %{success: false})
          error
      end

    new_state = %{state | verifications_performed: state.verifications_performed + 1}
    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:valid_hex?, input}, _from, state) do
    result = call_nif(:is_valid_hex_string, [input])
    {:reply, result == true, state}
  end

  # Private Functions

  defp call_nif(function, args) do
    try do
      case apply(:iota_nif, function, args) do
        {:ok, result} -> {:ok, result}
        {:error, reason} -> {:error, reason}
        result when is_binary(result) -> result
        result when is_boolean(result) -> result
        other -> {:ok, other}
      end
    rescue
      e ->
        Logger.error("NIF call #{function} raised: #{inspect(e)}")
        {:error, {:nif_exception, e}}
    catch
      kind, reason ->
        Logger.error("NIF call #{function} failed: #{kind} - #{inspect(reason)}")
        {:error, {kind, reason}}
    end
  end

  defp emit_telemetry(operation, start_time, metadata) do
    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      [:iota_service, :notarization, operation],
      %{duration: duration},
      metadata
    )
  end
end
