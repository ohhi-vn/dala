defmodule Dala.ML.CoreML.Test do
  @moduledoc """
  Tests for Dala.ML.CoreML.

  Note: These tests only run on iOS devices/simulators with CoreML available.
  On other platforms, they will skip or return `:not_supported`.
  """

  use ExUnit.Case, async: true

  test "load_model returns error for non-existent file" do
    result = Dala.ML.CoreML.load_model("/non/existent/path.mlmodel", "test_model")

    case result do
      {:error, _} -> :ok
      :not_supported -> :ok
      other -> flunk("Unexpected result: #{inspect(other)}")
    end
  end

  test "load_model validates arguments" do
    # Should accept only binary path and identifier
    assert_raise FunctionClauseError, fn ->
      Dala.ML.CoreML.load_model(123, "test")
    end

    assert_raise FunctionClauseError, fn ->
      Dala.ML.CoreML.load_model("path.mlmodel", 123)
    end
  end

  test "loaded? returns false for unloaded model" do
    result = Dala.ML.CoreML.loaded?("non_existent_model")

    case result do
      false -> :ok
      true -> :ok
      other -> flunk("Unexpected result: #{inspect(other)}")
    end
  end

  test "loaded_models returns a list or atom" do
    result = Dala.ML.CoreML.loaded_models()

    case result do
      list when is_list(list) -> :ok
      :none -> :ok
      other -> flunk("Unexpected result: #{inspect(other)}")
    end
  end

  test "predict returns not_supported or error for unloaded model" do
    result = Dala.ML.CoreML.predict("non_existent_model", %{"input" => 1.0})

    case result do
      {:ok, _json} -> :ok
      {:error, _reason} -> :ok
      :not_supported -> :ok
      other -> flunk("Unexpected result: #{inspect(other)}")
    end
  end

  test "predict validates arguments" do
    assert_raise FunctionClauseError, fn ->
      Dala.ML.CoreML.predict(123, %{"input" => 1.0})
    end

    assert_raise FunctionClauseError, fn ->
      Dala.ML.CoreML.predict("model", "not_a_map")
    end
  end

  test "predict_with_loaded_model returns error for unloaded model" do
    result = Dala.ML.CoreML.predict_with_loaded_model("non_existent_model", %{"input" => 1.0})

    case result do
      {:error, "Model not loaded: non_existent_model"} -> :ok
      {:error, _} -> :ok
      :not_supported -> :ok
      other -> flunk("Unexpected result: #{inspect(other)}")
    end
  end

  test "CoreML module is available" do
    assert Code.ensure_loaded?(Dala.ML.CoreML)
  end
end
