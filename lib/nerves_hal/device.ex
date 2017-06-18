defmodule Nerves.HAL.Device do

  defstruct [scope: [], subsystem: nil, devpath: nil,  attributes: []]

  @sysfs "/sys"

  def load([_ | devscope] = scope, subsystem) do
    devpath =
        Path.join([@sysfs, "/", Enum.join(devscope, "/")])

    %__MODULE__{
      scope: scope,
      devpath: devpath,
      subsystem: subsystem,
      attributes: []}
  end

  def load_attributes(devpath) do
    devpath = Path.join(devpath, "device")
    case File.ls(devpath) do
      {:ok, files} ->
        files
        |> Enum.map(&Path.join(devpath, &1))
        |> Enum.filter(&is_regular_file?/1)
        |> Enum.reduce(%{}, fn (file, acc) ->
            content =
              case File.read(file) do
                {:ok, data} -> data
                _ -> ""
              end
            attribute = Path.basename(file)
            Map.put(acc, attribute, %{content: content})
        end)
      _ -> %{}
    end
  end

  def device_file(device) do
      case File.read(uevent_file(device)) do
        {:ok, uevent} ->
          uevent_info =
            uevent
            |> String.strip
            |> String.split("\n")
            |> parse_uevent(%{})
          Path.join("/dev", Map.get(uevent_info, :devname, ""))
        _ -> nil
      end
  end

  def uevent_file(device) do
    Path.join(device.devpath, "uevent")
  end

  def parse_uevent([], acc), do: acc

  def parse_uevent([<<"MAJOR=", major :: binary>> | tail], acc) do
    major = Integer.parse(major)
    acc = Map.put(acc, :major, major)
    parse_uevent(tail, acc)
  end

  def parse_uevent([<<"MINOR=", minor :: binary>> | tail], acc) do
    minor = Integer.parse(minor)
    acc = Map.put(acc, :minor, minor)
    parse_uevent(tail, acc)
  end

  def parse_uevent([<<"DEVNAME=", devname :: binary>> | tail], acc) do
    acc = Map.put(acc, :devname, devname)
    parse_uevent(tail, acc)
  end

  def parse_uevent([_ | tail], acc), do: parse_uevent(tail, acc)

  def is_regular_file?(file) do
    case File.lstat(file) do
      {:ok, stat} -> stat.type == :regular
      _ -> false
    end
  end

end
