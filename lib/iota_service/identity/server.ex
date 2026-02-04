defmodule IotaService.Identity.Server do
  @moduledoc """
  GenServer for DID (Decentralized Identifier) operations.
  """

  use GenServer

  require Logger

  alias IotaService.Identity.Cache

  @default_network :iota

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec generate_did(keyword()) :: {:ok, map()} | {:error, term()}
  def generate_did(opts \\ []) do
    timeout = Keyword.get(opts, :timeout, 30_000)
    GenServer.call(__MODULE__, {:generate_did, opts}, timeout)
  end

  @spec valid_did?(String.t()) :: boolean()
  def valid_did?(did) when is_binary(did) do
    GenServer.call(__MODULE__, {:valid_did?, did})
  end

  @spec extract_did(String.t()) :: {:ok, String.t()} | {:error, term()}
  def extract_did(document_json) when is_binary(document_json) do
    GenServer.call(__MODULE__, {:extract_did, document_json})
  end

  @spec create_did_url(String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def create_did_url(did, fragment) when is_binary(did) and is_binary(fragment) do
    GenServer.call(__MODULE__, {:create_did_url, did, fragment})
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Identity Server started")

    state = %{
      generated_count: 0,
      last_generation: nil,
      errors: []
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:generate_did, opts}, _from, state) do
    network = Keyword.get(opts, :network, @default_network)
    cache? = Keyword.get(opts, :cache, true)

    start_time = System.monotonic_time()

    result =
      with {:ok, network_str} <- validate_network(network),
           {:ok, json} <- call_nif(:generate_did, [network_str]),
           {:ok, parsed} <- Jason.decode(json) do
        did_result = %{
          did: parsed["did"],
          document: parsed["document"],
          verification_method_fragment: parsed["verification_method_fragment"],
          network: network,
          generated_at: DateTime.utc_now()
        }

        if cache?, do: Cache.put(did_result.did, did_result)

        emit_telemetry(:generate_did, start_time, %{network: network, success: true})
        {:ok, did_result}
      else
        {:error, reason} = error ->
          emit_telemetry(:generate_did, start_time, %{network: network, success: false})
          Logger.warning("DID generation failed: #{inspect(reason)}")
          error
      end

    new_state =
      case result do
        {:ok, _} ->
          %{state | generated_count: state.generated_count + 1, last_generation: DateTime.utc_now()}

        {:error, reason} ->
          %{state | errors: [{DateTime.utc_now(), reason} | Enum.take(state.errors, 99)]}
      end

    {:reply, result, new_state}
  end

  @impl true
  def handle_call({:valid_did?, did}, _from, state) do
    result = call_nif(:is_valid_iota_did, [did])
    {:reply, result == {:ok, true}, state}
  end

  @impl true
  def handle_call({:extract_did, document_json}, _from, state) do
    result = call_nif(:extract_did_from_document, [document_json])
    {:reply, result, state}
  end

  @impl true
  def handle_call({:create_did_url, did, fragment}, _from, state) do
    result = call_nif(:create_did_url, [did, fragment])
    {:reply, result, state}
  end

  # Private Functions

  defp validate_network(network) when network in [:iota, :smr, :rms, :atoi] do
    {:ok, Atom.to_string(network)}
  end

  defp validate_network(network) when is_binary(network) and network in ["iota", "smr", "rms", "atoi"] do
    {:ok, network}
  end

  defp validate_network(network) do
    {:error, {:invalid_network, network}}
  end

  defp call_nif(function, args) do
    case apply(:iota_nif, function, args) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
      true -> {:ok, true}
      false -> {:ok, false}
      other -> {:ok, other}
    end
  catch
    :error, :badarg -> {:error, :badarg}
    kind, reason ->
      Logger.error("NIF call #{function} failed: #{kind} - #{inspect(reason)}")
      {:error, {kind, reason}}
  end

  defp emit_telemetry(operation, start_time, metadata) do
    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      [:iota_service, :identity, operation],
      %{duration: duration},
      metadata
    )
  end
end
