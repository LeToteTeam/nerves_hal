defmodule Nerves.HAL.Device do

  defstruct [subsystem: nil, devpath: nil,  attributes: []]

  def load(devpath, subsystem) when is_binary(subsystem) do
    load(devpath, String.to_atom(subsystem))
  end

  def load(devpath, subsystem) do
    %__MODULE__{
      devpath: devpath,
      subsystem: subsystem,
      attributes: load_attributes(devpath)}
  end

  def load_attributes(devpath) do
    devpath = Path.join(devpath, "device")
    case File.ls(devpath) do
      {:ok, files} ->
        files
        |> Enum.map(&Path.join(devpath, &1))
        |> Enum.filter(&is_regular_file?/1)
        |> Enum.reduce(%{}, fn (attribute, acc) ->
            lstat = File.lstat!(attribute)
            content =
              case File.read(attribute) do
                {:ok, data} -> data
                _ -> ""
              end
            Map.put(acc, attribute, %{lstat: lstat, content: content})
        end)
      _ -> %{}
    end
  end

  def device_file(device) do
    uevent_info =
      Path.join(device.devpath, "uevent")
      |> File.read!()
      |> String.strip
      |> String.split("\n")
      |> parse_uevent(%{})

    Path.join("/dev", Map.get(uevent_info, :devname, ""))
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
    stat = File.lstat!(file)
    stat.type == :regular 
  end

end
