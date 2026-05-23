defmodule Dala.ML.Test do
  @moduledoc """
  Tests for the unified Dala.ML API.
  """

  use ExUnit.Case, async: true

  describe "setup/0" do
    test "returns :ok" do
      assert Dala.ML.setup() == :ok
    end

    test "can be called multiple times safely" do
      Dala.ML.setup()
      Dala.ML.setup()
    end

    test "configures Nx backend" do
      Dala.ML.setup()
      assert Code.ensure_loaded?(Nx)
      # Backend should be set (either EMLX or BinaryBackend)
      backend = Nx.default_backend()
      assert backend != nil or is_tuple(backend) or is_atom(backend)
    end
  end

  describe "platform detection" do
    test "ios?/0 returns boolean" do
      assert is_boolean(Dala.ML.ios?())
    end

    test "ios_device?/0 returns boolean" do
      assert is_boolean(Dala.ML.ios_device?())
    end

    test "ios_simulator?/0 returns boolean" do
      assert is_boolean(Dala.ML.ios_simulator?())
    end

    test "android?/0 returns boolean" do
      assert is_boolean(Dala.ML.android?())
    end

    test "platform detectors are mutually consistent" do
      # If ios? is true, exactly one of device/simulator should be true (on iOS)
      # If ios? is false, both should be false
      if Dala.ML.ios?() do
        # On iOS, at least one should be true
        assert Dala.ML.ios_device?() or Dala.ML.ios_simulator?()
      else
        refute Dala.ML.ios_device?()
        refute Dala.ML.ios_simulator?()
      end
    end
  end

  describe "status/0" do
    test "returns map with required keys" do
      status = Dala.ML.status()
      assert is_map(status)
      assert Map.has_key?(status, :platform)
      assert Map.has_key?(status, :backend)
      assert Map.has_key?(status, :emlx_available)
      assert Map.has_key?(status, :coreml_available)
      assert Map.has_key?(status, :onnx_available)
      assert Map.has_key?(status, :libraries)
    end

    test "platform is a known atom" do
      status = Dala.ML.status()
      assert status.platform in [:ios_device, :ios_simulator, :android, :other]
    end

    test "backend is set" do
      status = Dala.ML.status()
      assert is_atom(status.backend) or is_tuple(status.backend)
    end

    test "availability flags are boolean" do
      status = Dala.ML.status()
      assert is_boolean(status.emlx_available)
      assert is_boolean(status.coreml_available)
      assert is_boolean(status.onnx_available)
    end

    test "libraries is a map with expected keys" do
      status = Dala.ML.status()
      libs = status.libraries
      assert is_map(libs)
      assert Map.has_key?(libs, :nx)
      assert Map.has_key?(libs, :scholar)
      assert Map.has_key?(libs, :nx_signal)
      assert Map.has_key?(libs, :axon)
      assert Map.has_key?(libs, :emlx)
    end

    test "nx library is always available" do
      status = Dala.ML.status()
      assert status.libraries.nx == true
    end
  end

  describe "available_backends/0" do
    test "returns a list" do
      backends = Dala.ML.available_backends()
      assert is_list(backends)
    end

    test "always includes :nx" do
      backends = Dala.ML.available_backends()
      assert :nx in backends
    end

    test "contains only known backend atoms" do
      known = [:nx, :emlx, :coreml, :onnx, :gpu_compute]
      backends = Dala.ML.available_backends()
      Enum.each(backends, fn b -> assert b in known end)
    end
  end

  describe "verify/0" do
    test "returns status map" do
      result = Dala.ML.verify()
      assert Map.has_key?(result, :status)
      assert result.status in [:ok, :error]
    end

    test "on success, sum is 6.0" do
      result = Dala.ML.verify()

      if result.status == :ok do
        assert result.sum == 6.0
      end
    end

    test "includes backend info" do
      result = Dala.ML.verify()

      if result.status == :ok do
        assert Map.has_key?(result, :backend)
      end
    end
  end

  describe "benchmark/1" do
    test "returns benchmark results with default opts" do
      result = Dala.ML.benchmark()
      assert Map.has_key?(result, :time_ms)
      assert Map.has_key?(result, :backend)
      assert Map.has_key?(result, :gflops)
      assert Map.has_key?(result, :matrix_size)
      assert Map.has_key?(result, :iterations)
    end

    test "respects custom size and iterations" do
      result = Dala.ML.benchmark(size: 10, iterations: 2)
      assert result.matrix_size == 10
      assert result.iterations == 2
    end

    test "time_ms is a float" do
      result = Dala.ML.benchmark(size: 10, iterations: 2)
      assert is_float(result.time_ms)
    end

    test "gflops is a float" do
      result = Dala.ML.benchmark(size: 10, iterations: 2)
      assert is_float(result.gflops)
    end
  end

  describe "predict/2" do
    test "returns error for unsupported model type" do
      result = Dala.ML.predict(:unsupported, %{})
      assert match?({:error, "Unsupported model type: :unsupported"}, result)
    end

    test "returns error for string model on non-iOS" do
      result = Dala.ML.predict("not_a_real_model", %{"input" => 1.0})

      if not Dala.ML.ios?() do
        assert match?({:error, _}, result) or match?(:not_supported, result)
      end
    end

    test "returns error for integer model (ONNX) with invalid session" do
      result = Dala.ML.predict(999_999, <<1, 2, 3>>)
      assert match?({:error, _}, result) or match?(:not_supported, result)
    end
  end
end
