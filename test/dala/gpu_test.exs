defmodule Dala.GpuTest do
  use ExUnit.Case, async: true

  alias Dala.Gpu.Command

  describe "command encoding" do
    test "encode_clear produces correct binary for named colors" do
      assert Command.encode_clear(:black) == <<0x01, 0, 0, 0, 255>>
      assert Command.encode_clear(:white) == <<0x01, 255, 255, 255, 255>>
      assert Command.encode_clear(:red) == <<0x01, 255, 0, 0, 255>>
      assert Command.encode_clear(:green) == <<0x01, 0, 255, 0, 255>>
      assert Command.encode_clear(:blue) == <<0x01, 0, 0, 255, 255>>
      assert Command.encode_clear(:transparent) == <<0x01, 0, 0, 0, 0>>
    end

    test "encode_clear produces correct binary for tuple colors" do
      assert Command.encode_clear({128, 64, 32}) == <<0x01, 128, 64, 32, 255>>
      assert Command.encode_clear({128, 64, 32, 200}) == <<0x01, 128, 64, 32, 200>>
    end

    test "encode_fill_rect produces correct size binary" do
      binary = Command.encode_fill_rect(10, 20, 100, 200, :red)
      # 1 byte opcode + 4 bytes x + 4 bytes y + 4 bytes w + 4 bytes h + 4 bytes RGBA = 21
      assert byte_size(binary) == 21
    end

    test "encode_fill_rect encodes coordinates correctly" do
      binary = Command.encode_fill_rect(10, 20, 100, 200, :red)

      assert binary ==
               <<0x02, 10::unsigned-little-32, 20::unsigned-little-32, 100::unsigned-little-32,
                 200::unsigned-little-32, 255, 0, 0, 255>>
    end

    test "encode_draw_line produces correct size binary" do
      binary = Command.encode_draw_line(0, 0, 255, 255, :white)
      # 1 byte opcode + 4*4 bytes coordinates + 4 bytes RGBA = 21
      assert byte_size(binary) == 21
    end

    test "encode_draw_line handles negative coordinates" do
      binary = Command.encode_draw_line(-10, -20, 100, 200, :blue)

      assert binary ==
               <<0x03, -10::signed-little-32, -20::signed-little-32, 100::signed-little-32,
                 200::signed-little-32, 0, 0, 255, 255>>
    end

    test "encode_blit produces correct size binary" do
      binary = Command.encode_blit(42, 10, 20)
      # 1 byte opcode + 8 bytes sprite_id + 4 bytes x + 4 bytes y = 17
      assert byte_size(binary) == 17
    end

    test "encode_blit encodes sprite_id as u64 LE" do
      binary = Command.encode_blit(0xDEADBEEF, -5, -10)

      assert binary ==
               <<0x04, 0xDEADBEEF::unsigned-little-64, -5::signed-little-32,
                 -10::signed-little-32>>
    end

    test "encode_present is a single byte" do
      assert Command.encode_present() == <<0x05>>
      assert byte_size(Command.encode_present()) == 1
    end

    test "encode_resize produces correct binary" do
      binary = Command.encode_resize(640, 480)
      assert byte_size(binary) == 9
      assert binary == <<0x06, 640::unsigned-little-32, 480::unsigned-little-32>>
    end

    test "encode_load_sprite includes pixel data" do
      pixel_data = <<255, 0, 0, 255, 0, 255, 0, 255>>
      binary = Command.encode_load_sprite(1, pixel_data, 2, 1)
      # 1 byte opcode + 8 bytes id + 4 bytes w + 4 bytes h + pixel data
      assert byte_size(binary) == 1 + 8 + 4 + 4 + 8

      assert binary ==
               <<0x07, 1::unsigned-little-64, 2::unsigned-little-32, 1::unsigned-little-32,
                 pixel_data::binary>>
    end

    test "encode_remove_sprite produces correct binary" do
      binary = Command.encode_remove_sprite(99)
      assert byte_size(binary) == 9
      assert binary == <<0x08, 99::unsigned-little-64>>
    end
  end

  describe "color encoding" do
    test "named colors" do
      assert Command.color_to_rgba(:black) == <<0, 0, 0, 255>>
      assert Command.color_to_rgba(:white) == <<255, 255, 255, 255>>
      assert Command.color_to_rgba(:red) == <<255, 0, 0, 255>>
      assert Command.color_to_rgba(:green) == <<0, 255, 0, 255>>
      assert Command.color_to_rgba(:blue) == <<0, 0, 255, 255>>
      assert Command.color_to_rgba(:transparent) == <<0, 0, 0, 0>>
    end

    test "3-tuple colors get alpha 255" do
      assert Command.color_to_rgba({128, 64, 32}) == <<128, 64, 32, 255>>
      assert Command.color_to_rgba({0, 0, 0}) == <<0, 0, 0, 255>>
      assert Command.color_to_rgba({255, 255, 255}) == <<255, 255, 255, 255>>
    end

    test "4-tuple colors preserve alpha" do
      assert Command.color_to_rgba({128, 64, 32, 200}) == <<128, 64, 32, 200>>
      assert Command.color_to_rgba({0, 0, 0, 0}) == <<0, 0, 0, 0>>
      assert Command.color_to_rgba({255, 255, 255, 128}) == <<255, 255, 255, 128>>
    end
  end

  describe "command binary structure" do
    test "all commands start with correct opcode byte" do
      assert :binary.at(Command.encode_clear(:black), 0) == 0x01
      assert :binary.at(Command.encode_fill_rect(0, 0, 1, 1, :black), 0) == 0x02
      assert :binary.at(Command.encode_draw_line(0, 0, 1, 1, :black), 0) == 0x03
      assert :binary.at(Command.encode_blit(0, 0, 0), 0) == 0x04
      assert :binary.at(Command.encode_present(), 0) == 0x05
      assert :binary.at(Command.encode_resize(1, 1), 0) == 0x06
      assert :binary.at(Command.encode_load_sprite(0, <<>>, 0, 0), 0) == 0x07
      assert :binary.at(Command.encode_remove_sprite(0), 0) == 0x08
    end
  end
end
