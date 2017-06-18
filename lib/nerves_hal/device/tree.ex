defmodule Nerves.HAL.Device.Tree do
  use GenStage
  alias Nerves.HAL.Device
  require Logger

  @subsystems [:state, "subsystems"]

  def start_link() do
    GenStage.start_link(__MODULE__, [], name: __MODULE__)
  end

  def register_handler(mod, pid \\ nil) do
    pid = pid || self()
    GenStage.call(__MODULE__, {:register_handler, mod, pid})
  end

  # GenStage API

  def init([]) do
    SystemRegistry.register()
    {:producer, %{
      handlers: [],
      subsystems: %{}
    }, dispatcher: GenStage.BroadcastDispatcher, buffer_size: 0}
  end

  def handle_events(_events, _from, s) do
    {:noreply, [], s}
  end

  def handle_demand(_demand, state) do
    {:noreply, [], state} # We don't care about the demand
  end

  # Server API

  def handle_call({:register_handler, mod, pid}, _from, s) do
    {adapter, _opts} = mod.__adapter__()
    subsystem = adapter.__subsystem__
    #IO.puts "Register handler #{inspect subsystem}"
    devices =
      Map.get(s.subsystems, subsystem, [])
      |> Enum.map(& Device.load(&1, subsystem))
    s = %{s | handlers: [{mod, pid} | s.handlers]}
    {:reply, {:ok, devices}, [], s}
  end

  def handle_info({:system_registry, :global, registry}, s) do
    subsystems = get_in(registry, @subsystems) || %{}
    modified =
      Enum.reduce(subsystems, [], fn
        ({subsystem, new}, acc) ->
          old = Map.get(s.subsystems, subsystem, [])
          {added, removed} = changes(new, old)
          added = Enum.map(added, &action(&1, subsystem, :add))
          removed = Enum.map(removed, &action(&1, subsystem, :remove))
          acc ++ added ++ removed
      end)
    old_subsystems = Map.keys(s.subsystems)
    new_subsystems = Map.keys(subsystems)

    removed =
      Enum.reject(old_subsystems, &Enum.member?(new_subsystems, &1))
      |> Enum.reduce([], fn
        (subsystem, acc) ->
          removed_devices =
            Map.get(s.subsystems, subsystem, [])
            |> Enum.map(&action(&1, subsystem, :remove))
          removed_devices ++ acc
      end)

    {:noreply, modified ++ removed, %{s | subsystems: subsystems}}
  end

  # Private Functions

  defp action(scope, subsystem, action) do
    device = Device.load(scope, subsystem)
    #IO.puts "#{inspect action} #{subsystem} #{inspect device.devpath}"
    {subsystem, action, device}
  end

  defp changes(new, new), do: {[], []}
  defp changes(new, old) do
    added = Enum.reject(new, &Enum.member?(old, &1))
    removed = Enum.reject(old, &Enum.member?(new, &1))
    {added, removed}
  end

end
