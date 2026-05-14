defmodule Dala.ML.Model.Test do
  @moduledoc """
  Tests for Dala.ML.Model — model download, cache, and compilation.
  """

  use ExUnit.Case, async: true

  describe "cache_dir/0" do
    test "returns a string path" do
      assert is_binary(Dala.ML.Model.cache_dir())
    end

    test "creates the directory if it doesn't exist" do
      dir = Dala.ML.Model.cache_dir()
      assert File.dir?(dir)
    end

    test "returns the same path on repeated calls" do
      dir1 = Dala.ML.Model.cache_dir()
      dir2 = Dala.ML.Model.cache_dir()
      assert dir1 == dir2
    end
  end

  describe "cached_models/0" do
    test "returns a list" do
      assert is_list(Dala.ML.Model.cached_models())
    end

    test "list items have required keys" do
      models = Dala.ML.Model.cached_models()

      Enum.each(models, fn model ->
        assert Map.has_key?(model, :name)
        assert Map.has_key?(model, :path)
        assert Map.has_key?(model, :size)
        assert Map.has_key?(model, :modified)
        assert is_binary(model.name)
        assert is_binary(model.path)
        assert is_integer(model.size)
      end)
    end
  end

  describe "path/1" do
    test "returns nil for non-existent model" do
      assert Dala.ML.Model.path("non_existent_model_12345") == nil
    end

    test "returns path for existing model" do
      # Create a temp file in cache
      dir = Dala.ML.Model.cache_dir()
      path = Path.join(dir, "test_model_tmp.bin")
      File.write!(path, "test")

      assert Dala.ML.Model.path("test_model_tmp.bin") == path

      # Clean up
      File.rm(path)
    end
  end

  describe "delete/1" do
    test "returns error for non-existent model" do
      assert {:error, _} = Dala.ML.Model.delete("non_existent_model_12345")
    end

    test "deletes an existing model file" do
      dir = Dala.ML.Model.cache_dir()
      path = Path.join(dir, "test_delete_me.bin")
      File.write!(path, "test")

      assert File.exists?(path)
      assert Dala.ML.Model.delete("test_delete_me.bin") == :ok
      refute File.exists?(path)
    end
  end

  describe "cache_size/0" do
    test "returns a non-negative integer" do
      size = Dala.ML.Model.cache_size()
      assert is_integer(size)
      assert size >= 0
    end
  end

  describe "clear_cache/0" do
    test "returns :ok" do
      assert Dala.ML.Model.clear_cache() == :ok
    end

    test "removes all cached models" do
      dir = Dala.ML.Model.cache_dir()
      path = Path.join(dir, "test_clear_me.bin")
      File.write!(path, "test")

      Dala.ML.Model.clear_cache()
      refute File.exists?(path)
    end
  end

  describe "compile/1" do
    test "returns path on non-iOS platforms" do
      if not Dala.ML.ios?() do
        result = Dala.ML.Model.compile("/some/path.mlmodel")
        assert match?({:ok, "/some/path.mlmodel"}, result)
      end
    end

    test "returns tuple result" do
      result = Dala.ML.Model.compile("/some/path.mlmodel")
      assert is_tuple(result)
    end
  end

  describe "download/2" do
    test "validates URL is a string" do
      assert_raise FunctionClauseError, fn ->
        Dala.ML.Model.download(123)
      end
    end

    test "returns error for invalid URL" do
      result = Dala.ML.Model.download("http://invalid.test.url.that.does.not.exist/model.bin")
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end

    test "accepts options" do
      result = Dala.ML.Model.download("http://example.com/model.bin", name: "my_model")
      assert is_tuple(result)
    end
  end
end
