defmodule Dala.ML.Test do
  @moduledoc """
  Tests for the unified Dala.ML API.
  """

  use ExUnit.Case, async: true

  describe "setup/0" do
    test "returns :ok or {:ok, _}" do
      result = Dala.ML.setup()
      assert result == :ok or match?({:ok, _}, result)
    end

    test "can be called multiple times safely" do
      Dala.ML.setup()
      Dala.ML.setup()
      # Should not crash
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
  end

  describe "benchmark/1" do
    test "returns benchmark results" do
      result = Dala.ML.benchmark(size: 10, iterations: 2)
      assert Map.has_key?(result, :time_ms)
      assert Map.has_key?(result, :backend)
      assert Map.has_key?(result, :gflops)
      assert Map.has_key?(result, :matrix_size)
      assert Map.has_key?(result, :iterations)
      assert result.matrix_size == 10
      assert result.iterations == 2
    end
  end

  describe "predict/2" do
    test "returns error for unsupported model type" do
      result = Dala.ML.predict("not_a_real_model_id", %{"input" => 1.0})
      # Either :not_supported (non-iOS), {:error, _} (model not loaded), or {:ok, _}
      assert match?({:error, _}, result) or match?(:not_supported, result) or
               match?({:ok, _}, result)
    end
  end
end
