defmodule Dala.Plugin.Protocol do
  @moduledoc """
  Generates binary protocol specifications from plugin schemas.

  This module auto-generates field mappings and encoders for plugin-defined
  properties, preventing protocol chaos through systematic field numbering.

  ## Field Numbering

  Each property in a component gets a unique field number:

      prop "volume", :f32
      # → FIELD_VOLUME = 0x07
      # → [f32]

  Field numbers are assigned sequentially starting from 0x01 for each
  component, ensuring no collisions within a plugin.

  ## Binary Format

  The protocol uses a compact binary format:

      +--------+--------+--------+--------+
      | opcode |  id    | field  | value  |
      +--------+--------+--------+--------+
        1 byte  8 bytes  1 byte  N bytes

  Where:
    - opcode: CREATE_NODE, UPDATE_PROP, etc.
    - id: 64-bit node identifier
    - field: field number (0x01-0xFF)
    - value: type-encoded value

  ## Type Encoding

  | Type  | Tag | Size | Format       |
  |-------|-----|------|--------------|
  | string| 0x01| var  | UTF-8 + len  |
  | bool  | 0x02| 1    | 0x00/0x01    |
  | int   | 0x03| 8    | signed 64-bit|
  | float | 0x04| 8    | 64-bit IEEE  |
  | f32   | 0x05| 4    | 32-bit IEEE  |
  | f64   | 0x06| 8    | 64-bit IEEE  |
  | color | 0x07| 4    | ARGB         |
  | binary| 0x08| var  | len + data   |

  ## Example

      defmodule MyApp.VideoPlugin do
        use Dala.Plugin

        component "video" do
          prop "source", :string
          prop "volume", :f32
          prop "autoplay", :bool
        end
      end

  Generates:

      FIELD_SOURCE = 0x01
      FIELD_VOLUME = 0x02
      FIELD_AUTOPLAY = 0x03

      # Encoding {"video.mp4", 0.8, true}:
      # 01 00 00 00 00 00 00 00 00  # id (8 bytes)
      # 01 0B 76 69 64 65 6F 2E 6D  # field 01, string "video.mp4"
      # 70 02 00 00 00 00 02 03 10  # field 02, f32 0.8
      # 03 01                       # field 03, bool true
  """

  alias Dala.Plugin.Component

  @type field_number :: 0x00..0xFF
  # string
  @type type_tag ::
          0x01
          # bool
          | 0x02
          # integer
          | 0x03
          # float
          | 0x04
          # f32
          | 0x05
          # f64
          | 0x06
          # color
          | 0x07
          # binary
          | 0x08
          # list
          | 0x09
          # map
          | 0x0A

  @doc """
  Generates protocol specification for a plugin.

  Returns a map containing field mappings and encoding helpers.
  """
  @spec generate(Dala.Plugin.t()) :: map()
  def generate(plugin) do
    components =
      Enum.map(plugin.components, fn {_name, component} ->
        generate_component(component)
      end)

    %{
      plugin: plugin.name,
      schema_version: plugin.schema_version,
      protocol_version: plugin.protocol_version,
      components: components,
      field_map: build_field_map(components)
    }
  end

  @doc """
  Generates field mappings for a single component.
  """
  @spec generate_component(Component.t()) :: map()
  def generate_component(component) do
    {fields, _} =
      Enum.map_reduce(component.props, 1, fn prop, num ->
        field = %{
          name: prop.name,
          number: num,
          type: prop.type,
          type_tag: type_to_tag(prop.type),
          required: prop.required,
          default: prop.default
        }

        {field, num + 1}
      end)

    %{
      component: component.name,
      plugin: component.plugin,
      fields: fields,
      field_by_name: Map.new(fields, &{&1.name, &1}),
      field_by_number: Map.new(fields, &{&1.number, &1}),
      event_names: Enum.map(component.events, & &1.name),
      native_mappings: component.natives,
      capabilities: component.capabilities
    }
  end

  @doc """
  Builds a global field map for quick lookup.
  """
  @spec build_field_map([map()]) :: %{String.t() => map()}
  def build_field_map(components) do
    Enum.reduce(components, %{}, fn comp, acc ->
      Map.put(acc, comp.component, comp.field_by_name)
    end)
  end

  @doc """
  Converts a prop type to its binary type tag.
  """
  @spec type_to_tag(Component.prop_type()) :: type_tag()
  def type_to_tag(:string), do: 0x01
  def type_to_tag(:bool), do: 0x02
  def type_to_tag(:integer), do: 0x03
  def type_to_tag(:float), do: 0x04
  def type_to_tag(:f32), do: 0x05
  def type_to_tag(:f64), do: 0x06
  def type_to_tag(:color), do: 0x07
  def type_to_tag(:binary), do: 0x08
  def type_to_tag(:list), do: 0x09
  def type_to_tag(:map), do: 0x0A

  @doc """
  Encodes a value according to its type tag.
  """
  @spec encode_value(type_tag(), term()) :: binary()
  def encode_value(0x01, value) when is_binary(value) do
    <<0x01, byte_size(value)::16, value::binary>>
  end

  def encode_value(0x02, true), do: <<0x02, 0x01>>
  def encode_value(0x02, false), do: <<0x02, 0x00>>
  def encode_value(0x02, 1), do: <<0x02, 0x01>>
  def encode_value(0x02, 0), do: <<0x02, 0x00>>

  def encode_value(0x03, value) when is_integer(value) do
    <<0x03, value::signed-64>>
  end

  def encode_value(0x04, value) when is_float(value) do
    <<0x04, value::float-64>>
  end

  def encode_value(0x05, value) when is_float(value) do
    <<0x05, value::float-32>>
  end

  def encode_value(0x06, value) when is_float(value) do
    <<0x06, value::float-64>>
  end

  def encode_value(0x07, value) when is_integer(value) do
    <<0x07, value::unsigned-32>>
  end

  def encode_value(0x08, value) when is_binary(value) do
    <<0x08, byte_size(value)::32, value::binary>>
  end

  def encode_value(0x09, value) when is_list(value) do
    encoded = Enum.map(value, &encode_value(0x01, to_string(&1)))
    data = IO.iodata_to_binary(encoded)
    <<0x09, byte_size(data)::32, data::binary>>
  end

  def encode_value(0x0A, value) when is_map(value) do
    encoded =
      Enum.map(value, fn {k, v} ->
        [encode_value(0x01, to_string(k)), encode_value(0x01, to_string(v))]
      end)
      |> IO.iodata_to_binary()

    <<0x0A, byte_size(encoded)::32, encoded::binary>>
  end

  @doc """
  Encodes a property update for a node.
  """
  @spec encode_prop_update(String.t(), field_number(), type_tag(), term()) :: binary()
  def encode_prop_update(node_id, field_number, type_tag, value) do
    field_data = encode_value(type_tag, value)
    <<node_id::unsigned-64, field_number, field_data::binary>>
  end

  @doc """
  Generates example encoded data for documentation.
  """
  @spec example_encoding(Component.t()) :: String.t()
  def example_encoding(component) do
    IO.inspect(component, label: "Component #{component.name}")
    "Example encoding for #{component.name}"
  end
end
