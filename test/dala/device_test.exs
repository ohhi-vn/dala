defmodule Dala.DeviceTest do
  use ExUnit.Case, async: false

  alias Dala.Device.Device

  setup do
    start_supervised!({Dala.Device.Ios, []})
    start_supervised!({Dala.Device.Android, []})
    start_supervised!({Dala.Device.Device, []})

    :ok
  end

  # ── NIF availability helper ############################################---

  # Returns true only when the locale NIF functions are actually callable.
  # The NIF module may partially load (some functions exist, others don't),
  # so we probe for the specific new functions we care about.
  defp nif_locale_loaded? do
    try do
      Dala.Platform.Native.device_locale()
      true
    rescue
      ErlangError -> false
      UndefinedFunctionError -> false
    end
  end

  # Helper: assert that a function raises any error (NIF not loaded).
  # Covers both ErlangError (NIF loaded but function returns error tuple)
  # and UndefinedFunctionError (NIF partially loaded, function missing).
  defp assert_raises_nif_error(fun) do
    try do
      fun.()
      flunk("Expected an exception but none was raised")
    rescue
      _ in [ErlangError, UndefinedFunctionError] -> :ok
    end
  end

  # ── locale/0 ##############################################################

  describe "locale/0" do
    test "returns a non-empty string when NIF is loaded" do
      if nif_locale_loaded?() do
        locale = Device.locale()
        assert is_binary(locale)
        assert byte_size(locale) > 0
      end
    end

    test "does not return the fallback atom as a string when NIF is loaded" do
      if nif_locale_loaded?() do
        locale = Device.locale()
        refute locale == "unknown"
      end
    end

    test "raises when NIF is not loaded" do
      unless nif_locale_loaded?() do
        assert_raises_nif_error(fn -> Device.locale() end)
      end
    end
  end

  # ── language/0 ############################################################

  describe "language/0" do
    test "returns a non-empty string when NIF is loaded" do
      if nif_locale_loaded?() do
        language = Device.language()
        assert is_binary(language)
        assert byte_size(language) > 0
      end
    end

    test "returns a lowercase language code when NIF is loaded" do
      if nif_locale_loaded?() do
        language = Device.language()
        assert language == String.downcase(language)
        assert byte_size(language) >= 2
      end
    end

    test "raises when NIF is not loaded" do
      unless nif_locale_loaded?() do
        assert_raises_nif_error(fn -> Device.language() end)
      end
    end
  end

  # ── region/0 ##############################################################

  describe "region/0" do
    test "returns a non-empty string when NIF is loaded" do
      if nif_locale_loaded?() do
        region = Device.region()
        assert is_binary(region)
        assert byte_size(region) > 0
      end
    end

    test "returns an uppercase region code when NIF is loaded" do
      if nif_locale_loaded?() do
        region = Device.region()
        assert region == String.upcase(region)
        assert byte_size(region) >= 2
      end
    end

    test "raises when NIF is not loaded" do
      unless nif_locale_loaded?() do
        assert_raises_nif_error(fn -> Device.region() end)
      end
    end
  end

  # ── Consistency between locale, language, and region ######################

  describe "locale/language/region consistency" do
    test "language code appears in locale identifier when NIF is loaded" do
      if nif_locale_loaded?() do
        locale = Device.locale()
        language = Device.language()
        assert String.starts_with?(locale, language)
      end
    end

    test "region code appears in locale identifier when NIF is loaded" do
      if nif_locale_loaded?() do
        locale = Device.locale()
        region = Device.region()

        if byte_size(region) > 0 do
          assert String.contains?(locale, region)
        end
      end
    end
  end

  # ── Existing device queries still work ####################################

  describe "existing device queries" do
    test "battery_state returns an atom when NIF is loaded" do
      if nif_locale_loaded?() do
        state = Device.battery_state()
        assert state in [:unplugged, :charging, :full, :unknown]
      end
    end

    test "battery_level returns an integer when NIF is loaded" do
      if nif_locale_loaded?() do
        level = Device.battery_level()
        assert is_integer(level)
        assert level >= -1 and level <= 100
      end
    end

    test "thermal_state returns an atom when NIF is loaded" do
      if nif_locale_loaded?() do
        state = Device.thermal_state()
        assert state in [:nominal, :fair, :serious, :critical]
      end
    end

    test "low_power_mode? returns a boolean when NIF is loaded" do
      if nif_locale_loaded?() do
        result = Device.low_power_mode?()
        assert is_boolean(result)
      end
    end

    test "foreground? returns a boolean when NIF is loaded" do
      if nif_locale_loaded?() do
        result = Device.foreground?()
        assert is_boolean(result)
      end
    end

    test "os_version returns a string when NIF is loaded" do
      if nif_locale_loaded?() do
        version = Device.os_version()
        assert is_binary(version)
      end
    end

    test "model returns a string when NIF is loaded" do
      if nif_locale_loaded?() do
        model = Device.model()
        assert is_binary(model)
      end
    end
  end

  # ── GenServer lifecycle ###################################################

  describe "GenServer lifecycle" do
    test "subscribe and unsubscribe do not crash" do
      assert Device.subscribe() == :ok
      assert Device.unsubscribe() == :ok
    end

    test "subscribe with specific categories works" do
      assert Device.subscribe([:app, :power]) == :ok
      assert Device.unsubscribe() == :ok
    end

    test "subscribe with :all works" do
      assert Device.subscribe(:all) == :ok
      assert Device.unsubscribe() == :ok
    end

    test "categories/0 returns the expected list" do
      cats = Device.categories()
      assert :app in cats
      assert :display in cats
      assert :audio in cats
      assert :appearance in cats
      assert :power in cats
      assert :thermal in cats
      assert :memory in cats
    end
  end

  # ── NIF raw function tests (platform.Native) ##############################

  describe "Dala.Platform.Native locale functions" do
    test "device_locale returns a binary when NIF is loaded" do
      if nif_locale_loaded?() do
        result = Dala.Platform.Native.device_locale()
        assert is_binary(result)
        assert byte_size(result) > 0
      end
    end

    test "device_language returns a binary when NIF is loaded" do
      if nif_locale_loaded?() do
        result = Dala.Platform.Native.device_language()
        assert is_binary(result)
        assert byte_size(result) > 0
      end
    end

    test "device_region returns a binary when NIF is loaded" do
      if nif_locale_loaded?() do
        result = Dala.Platform.Native.device_region()
        assert is_binary(result)
        assert byte_size(result) > 0
      end
    end

    test "all three NIF functions raise when NIF is not loaded" do
      unless nif_locale_loaded?() do
        assert_raises_nif_error(fn -> Dala.Platform.Native.device_locale() end)
        assert_raises_nif_error(fn -> Dala.Platform.Native.device_language() end)
        assert_raises_nif_error(fn -> Dala.Platform.Native.device_region() end)
      end
    end
  end
end
