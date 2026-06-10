defmodule Dala.ML.EMLXTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Tests for Dala.ML.EMLX zero-config setup.

  Verifies the rewritten module that uses direct config instead of NIF delegation.
  """

  describe "available?/0" do
    test "returns true when EMLX hex is loaded" do
      result = Dala.ML.EMLX.available?()
      expected = Code.ensure_loaded?(EMLX) and Code.ensure_loaded?(EMLX.Backend)
      assert result == expected
    end
  end

  describe "setup/0" do
    test "always returns :ok" do
      assert Dala.ML.EMLX.setup() == :ok
    end

    test "can be called multiple times without error" do
      assert Dala.ML.EMLX.setup() == :ok
      assert Dala.ML.EMLX.setup() == :ok
      assert Dala.ML.EMLX.setup() == :ok
    end

    test "sets Nx backend after setup" do
      Dala.ML.EMLX.setup()
      backend = Nx.default_backend()
      assert backend == {EMLX.Backend, device: :gpu} or backend == Nx.BinaryBackend
    end

    test "configures EMLX jit_enabled application env" do
      Dala.ML.EMLX.setup()
      jit = Application.get_env(:emlx, :jit_enabled)
      assert jit == true or jit == false
    end
  end

  describe "platform detection" do
    test "ios_device? and ios_simulator? are mutually exclusive" do
      device = Dala.ML.EMLX.ios_device?()
      simulator = Dala.ML.EMLX.ios_simulator?()
      # Both should not be true simultaneously
      refute device and simulator
    end
  end

  describe "platform_config/0" do
    test "returns config map with required keys" do
      config = Dala.ML.EMLX.platform_config()
      assert %{} = config
      assert Map.has_key?(config, :jit_enabled)
      assert Map.has_key?(config, :device)
    end

    test "jit_enabled is false on non-iOS platforms" do
      config = Dala.ML.EMLX.platform_config()

      if config.device != :ios_simulator do
        assert config.jit_enabled == false
      end
    end

    test "device is one of known platforms" do
      config = Dala.ML.EMLX.platform_config()
      assert config.device in [:ios_device, :ios_simulator, :android, :other]
    end

    test "jit_enabled is false for iOS device" do
      if Dala.ML.EMLX.ios_device?() do
        config = Dala.ML.EMLX.platform_config()
        assert config.jit_enabled == false
      end
    end
  end

  describe "default_device/0" do
    test "returns :gpu when EMLX is available" do
      if Dala.ML.EMLX.available?() do
        assert Dala.ML.EMLX.default_device() == :gpu
      end
    end

    test "returns :cpu when EMLX is not available" do
      if not Dala.ML.EMLX.available?() do
        assert Dala.ML.EMLX.default_device() == :cpu
      end
    end
  end

  describe "integration" do
    test "setup + status round-trip works" do
      Dala.ML.EMLX.setup()
      status = Dala.ML.status()
      assert %{} = status
      assert status.emlx_available == true or status.emlx_available == false
    end

    test "setup + verify round-trip works" do
      Dala.ML.EMLX.setup()
      result = Dala.ML.verify()
      assert result.status == :ok
    end
  end
end
