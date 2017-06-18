defmodule Nerves.HAL.Device.Tree do
  use GenStage

  require Logger

  @sysfs "/sys"

  def start_link() do
    {:ok, pid} = GenStage.start_link(__MODULE__, [], name: __MODULE__)
    GenStage.sync_subscribe(pid, to: Nerves.Runtime.Kernel.UEvent)
    {:ok, pid}
  end

  def register_handler(mod, pid \\ nil) do
    pid = pid || self()
    GenStage.call(__MODULE__, {:register_handler, mod, pid})
  end

  def devices() do
    GenStage.call(__MODULE__, :devices)
  end

  # GenStage API

  def init([]) do
    {:producer_consumer, %{
      handlers: [],
      devices: discover_devices(),
    }, dispatcher: GenStage.BroadcastDispatcher, buffer_size: 0}
  end

  def handle_events([{:uevent, _, %{action: "add"} = data}], _from, s) do
    device =
      Path.join(@sysfs, data.devpath)
      |> Nerves.HAL.Device.load
    devices = s.devices
    subsystem = String.to_atom(data.subsystem)
    subsystem_devices = Keyword.get(devices, subsystem, [])
    devices = Keyword.put(s.devices, subsystem, [device | subsystem_devices])

    {:noreply, [{subsystem, :add, device}], %{s | devices: devices}}
  end

  def handle_events([{:uevent, _, %{action: "remove"} = data}], _from, s) do
    subsystem = String.to_atom(data.subsystem)
    subsystem_devices =
      s.devices
      |> Keyword.get(subsystem, [])
      |> Enum.filter(& &1.subsystem == subsystem)
    event_devpath = Path.join(@sysfs, data.devpath)
    device = Enum.find(subsystem_devices, & &1.devpath == event_devpath)

    subsystem_devices =
      case device do
        %Nerves.HAL.Device{devpath: devpath} ->
          Enum.reject(subsystem_devices, & &1.devpath == devpath)
        _ -> subsystem_devices
      end
    devices = Keyword.put(s.devices, subsystem, subsystem_devices)
    {:noreply, [{subsystem, :remove, device}], %{s | devices: devices}}
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
    devices = Keyword.get(s.devices, subsystem, [])
    s = %{s | handlers: [{mod, pid} | s.handlers]}
    {:reply, {:ok, devices}, [], s}
  end

  def handle_call(:devices, _from, s) do
    {:reply, {:ok, s.devices}, [], s}
  end

  # Private Functions

  defp discover_devices do
    bus_dir = "/sys/bus"
    File.ls!(bus_dir)
    |> Enum.reduce([], fn(bus, acc) ->
      path = Path.join(bus_dir, bus)
      devices_dir = Path.join(path, "devices")
      case File.ls(devices_dir) do
        {:ok, devices} ->
          acc ++ load_devices(devices_dir)
        _ -> acc
      end
    end)
  end

  defp load_devices(path) do
    path
    |> File.ls!()
    |> Enum.map(& Path.join(path, &1))
    |> Enum.reject(& File.lstat!(&1).type != :symlink)
    |> Enum.map(& expand_symlink(&1, path))
    |> Enum.map(& Nerves.HAL.Device.load/1)
  end

  defp expand_symlink(path, dir) do
    {:ok, link} = :file.read_link(String.to_char_list(path))
    link
    |> to_string
    |> Path.expand(dir)
  end

end
