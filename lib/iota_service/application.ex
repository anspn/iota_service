defmodule IotaService.Application do
  @moduledoc """
  IOTA Service Application

  ## Supervision Tree Structure

  ```
  IotaService.Application (rest_for_one)
  ├── IotaService.NIF.Loader          # Ensures NIF is loaded before other services
  ├── IotaService.Identity.Supervisor  # DID-related services (one_for_one)
  │   ├── IotaService.Identity.Server  # GenServer for DID operations
  │   └── IotaService.Identity.Cache   # ETS-backed DID document cache
  └── IotaService.Notarization.Supervisor  # Notarization services (one_for_one)
      ├── IotaService.Notarization.Server  # GenServer for notarization ops
      └── IotaService.Notarization.Queue   # Pending notarization queue
  ```

  ## Strategy Rationale

  - **rest_for_one** at root: If NIF.Loader crashes, restart everything downstream
    since all services depend on the NIF being loaded.
  - **one_for_one** for domain supervisors: Independent services within a domain
    should not affect each other.
  """

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting IOTA Service application")

    children = [
      # 1. NIF Loader - must start first
      # If this crashes, all downstream services restart
      IotaService.NIF.Loader,

      # 2. Identity Domain Supervisor
      {IotaService.Identity.Supervisor, []},

      # 3. Notarization Domain Supervisor
      {IotaService.Notarization.Supervisor, []}
    ]

    # rest_for_one: if NIF.Loader crashes, restart Identity and Notarization supervisors
    opts = [strategy: :rest_for_one, name: IotaService.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        Logger.info("IOTA Service started successfully")
        {:ok, pid}

      {:error, reason} = error ->
        Logger.error("Failed to start IOTA Service: #{inspect(reason)}")
        error
    end
  end

  @impl true
  def stop(_state) do
    Logger.info("Stopping IOTA Service application")
    :ok
  end
end
