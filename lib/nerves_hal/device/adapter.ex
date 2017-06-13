defmodule Nerves.HAL.Device.Adapter do
  alias Nerves.HAL.Device

  @callback attributes(Device.t) :: map

  defmacro __using__(opts) do
    quote do
      use GenServer
      @behaviour Nerves.HAL.Device.Adapter
      @subsystem unquote(opts[:subsystem])

      def __subsystem__, do: @subsystem

      def attributes(_dev), do: %{}

      def start_link(adapter_opts \\ []) do
        Nerves.HAL.Device.Adapter.start_link(__MODULE__, self(), adapter_opts)
      end

      def stop(pid) do
        GenServer.stop(pid)
      end

      def connect(pid, device) do
        GenServer.call(pid, {:connect, device})
      end

      defoverridable [attributes: 1]
    end
  end

  def start_link(mod, handler, adapter_opts) do
    GenServer.start_link(__MODULE__, {mod, handler, adapter_opts})
  end

  def call(pid, call, timeout \\ 5000) do
    GenServer.call(pid, call, timeout)
  end

  def cast(pid, request) do
    GenServer.cast(pid, request)
  end

  def init({mod, handler, adapter_opts}) do
    {:ok, %{
      handler: handler,
      adapter_state: %{opts: adapter_opts},
      mod: mod
    }}
  end

  def handle_info(data, s) do
    s =
      case s.mod.handle_info(data, s.adapter_state) do
        {:data_in, data, adapter_state} ->
          send(s.handler, {:adapter, :data_in, data})
          put_in(s, [:adapter_state], adapter_state)
      end
    {:noreply, s}
  end

  def handle_call({:connect, device}, _from, s) do
    case s.mod.handle_connect(device, s.adapter_state) do
      {:ok, adapter_state} ->
        s = put_in(s, [:adapter_state], adapter_state)
        {:reply, :ok, s}
      {:error, error, s} ->
        {:reply, {:error, error}, s}
    end
  end

  def handle_call(request, from, s) do
    case s.mod.handle_call(request, from, s.adapter_state) do
      {:noreply, adapter_state} ->
        {:noreply, put_in(s, [:adapter_state], adapter_state)}
      {:reply, reply, adapter_state} ->
        {:reply, reply, put_in(s, [:adapter_state], adapter_state)}
    end
  end

  def handle_cast(request, s) do
    case s.mod.handle_cast(request, s.adapter_state) do
      {:noreply, adapter_state} ->
        {:noreply, put_in(s, [:adapter_state], adapter_state)}
    end
  end
end
