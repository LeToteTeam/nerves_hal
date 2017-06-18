defmodule Nerves.HAL.Device do

  defstruct [subsystem: nil, devpath: nil,  attributes: []]

  def load(devpath, subsystem) when is_binary(subsystem) do
    load(devpath, String.to_atom(subsystem))
  end

  def load(devpath) do
    %__MODULE__{
      devpath: devpath,
      subsystem: subsystem(devpath),
      attributes: load_attributes(devpath)}
  end

  def subsystem(devpath) do
    subsystem = Path.join(devpath, "subsystem")
    if File.dir?(subsystem) do
      expand_symlink(subsystem, devpath)
      |> Path.basename
    end
  end

  def load_attributes(devpath) do
    case File.ls(devpath) do
      {:ok, files} ->
        files
        |> Enum.map(&Path.join(devpath, &1))
        |> Enum.filter(&is_regular_file?/1)
        |> Enum.reduce(%{}, fn (file, acc) ->
            lstat = File.lstat!(file)
            content =
              case File.read(file) do
                {:ok, data} -> data
                _ -> ""
              end
            attribute = Path.basename(file)
            attribute_action(attribute, content)
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

  # Automatically modprobe the modalias to load the module for the device driver
  def attribute_action("modalias", content) do
    alias = String.strip(content)
    System.cmd("modprobe", [alias], stderr_to_stdout: true)
    |> IO.inspect
  end

  def attribute_action(_, _), do: :noop

  defp expand_symlink(path, dir) do
    {:ok, link} = :file.read_link(String.to_char_list(path))
    link
    |> to_string
    |> Path.expand(dir)
  end

end
