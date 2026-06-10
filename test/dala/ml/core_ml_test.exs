defmodule Dala.ML.CoreML.Test do
  @moduledoc """
  Tests for Dala.ML.CoreML.

  Verifies the rewritten module that uses Dala.Native NIF functions directly.
  On non-iOS platforms, most operations return :not_supported.
  """

  use ExUnit.Case, async: true

  describe "module loading" do
    test "CoreML module is available" do
      assert Code.ensure_loaded?(Dala.ML.CoreML) == true
    end
  end

  describe "load_model/2" do
    test "returns error for non-existent file" do
      result = Dala.ML.CoreML.load_model("/non/existent/path.mlmodel", "test_model")

      assert match?({:error, _}, result) or match?(:not_supported, result)
    end

    test "validates path argument type" do
      assert_raise FunctionClauseError, fn ->
        Dala.ML.CoreML.load_model(123, "test")
      end
    end

    test "validates identifier argument type" do
      assert_raise FunctionClauseError, fn ->
        Dala.ML.CoreML.load_model("path.mlmodel", 123)
      end
    end

    test "accepts valid binary arguments" do
      result = Dala.ML.CoreML.load_model("valid_path.mlmodel", "valid_id")
      assert match?({:error, _}, result) or result == :not_supported
    end
  end

  describe "unload_model/1" do
    test "accepts binary identifier" do
      result = Dala.ML.CoreML.unload_model("some_model")
      assert result == :ok or result == :not_supported
    end

    test "validates argument type" do
      assert_raise FunctionClauseError, fn ->
        Dala.ML.CoreML.unload_model(123)
      end
    end
  end

  describe "loaded?/1" do
    test "returns false for any identifier on non-iOS" do
      result = Dala.ML.CoreML.loaded?("non_existent_model")
      assert result == false
    end

    test "returns false for unloaded model" do
      result = Dala.ML.CoreML.loaded?("definitely_not_loaded_#{:erlang.unique_integer()}")
      assert result == false
    end

    test "validates argument type" do
      assert_raise FunctionClauseError, fn ->
        Dala.ML.CoreML.loaded?(123)
      end
    end
  end

  describe "loaded_models/0" do
    test "returns a list" do
      result = Dala.ML.CoreML.loaded_models()
      assert result == []
    end

    test "list contains only strings" do
      result = Dala.ML.CoreML.loaded_models()
      assert Enum.all?(result, &is_binary/1)
    end
  end

  describe "predict/2" do
    test "returns error or not_supported for unloaded model" do
      result = Dala.ML.CoreML.predict("non_existent_model", %{"input" => 1.0})
      assert match?({:error, _}, result) or match?(:not_supported, result)
    end

    test "validates identifier argument type" do
      assert_raise FunctionClauseError, fn ->
        Dala.ML.CoreML.predict(123, %{"input" => 1.0})
      end
    end

    test "validates inputs argument type" do
      assert_raise FunctionClauseError, fn ->
        Dala.ML.CoreML.predict("model", "not_a_map")
      end
    end

    test "accepts valid arguments" do
      result = Dala.ML.CoreML.predict("model_id", %{"input" => [1.0, 2.0]})
      assert match?({:error, _}, result) or result == :not_supported
    end
  end

  describe "predict_with_loaded_model/2" do
    test "returns specific error for unloaded model" do
      unique = "unloaded_#{:erlang.unique_integer([:positive])}"
      result = Dala.ML.CoreML.predict_with_loaded_model(unique, %{"input" => 1.0})

      if result == :not_supported do
        :ok
      else
        assert match?({:error, "Model not loaded: " <> _}, result)
      end
    end

    test "validates argument types" do
      assert_raise FunctionClauseError, fn ->
        Dala.ML.CoreML.predict_with_loaded_model(123, %{})
      end

      assert_raise FunctionClauseError, fn ->
        Dala.ML.CoreML.predict_with_loaded_model("model", "not_a_map")
      end
    end
  end

  describe "full lifecycle" do
    test "load → check → unload → check sequence" do
      model_id = "lifecycle_test_#{:erlang.unique_integer([:positive])}"

      # Load (may fail on non-existent file)
      load_result = Dala.ML.CoreML.load_model("/non/existent.mlmodel", model_id)

      if load_result == :not_supported do
        :ok
      else
        # loaded? should return a boolean
        _ = Dala.ML.CoreML.loaded?(model_id)

        # Unload should succeed
        assert Dala.ML.CoreML.unload_model(model_id) == :ok or
                 Dala.ML.CoreML.unload_model(model_id) == :not_supported
      end
    end
  end
end
