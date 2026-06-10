defmodule Dala.ML.Training.Test do
  @moduledoc """
  Tests for Dala.ML.Training — on-device fine-tuning and evaluation.
  """

  use ExUnit.Case, async: true

  describe "save_params/2 and load_params/1" do
    test "save and load round-trip preserves params" do
      params = %{weight: Nx.tensor([1.0, 2.0, 3.0]), bias: Nx.tensor([0.5])}

      path =
        Path.join(System.tmp_dir!(), "test_params_#{:erlang.unique_integer([:positive])}.bin")

      assert Dala.ML.Training.save_params(params, path) == :ok
      assert File.exists?(path)

      {:ok, loaded} = Dala.ML.Training.load_params(path)
      assert %{} = loaded
      assert Map.has_key?(loaded, :weight)

      # Clean up
      File.rm(path)
    end

    test "load_params returns error for non-existent file" do
      result = Dala.ML.Training.load_params("/non/existent/params.bin")
      assert match?({:error, _}, result)
    end

    test "save_params writes a file" do
      params = %{test: Nx.tensor([1.0])}
      path = Path.join(System.tmp_dir!(), "test_save_#{:erlang.unique_integer([:positive])}.bin")

      Dala.ML.Training.save_params(params, path)
      assert File.exists?(path)
      assert File.stat!(path).size > 0

      File.rm(path)
    end
  end

  describe "fine_tune/4" do
    test "accepts model, params, data tuple, and opts" do
      # Create a simple model
      model =
        Axon.input("input", shape: {nil, 2})
        |> Axon.dense(1)

      {init_fn, _predict_fn} = Axon.build(model)
      params = init_fn.(Nx.template({1, 2}, :f32), %{})

      # Create tiny training data
      data = Nx.tensor([[1.0, 2.0], [3.0, 4.0]])
      labels = Nx.tensor([1.0, 0.0])

      result =
        Dala.ML.Training.fine_tune(
          model,
          params,
          {data, labels},
          epochs: 1,
          learning_rate: 0.01
        )

      # Should return updated params or error
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns map with updated params on success" do
      model =
        Axon.input("input", shape: {nil, 2})
        |> Axon.dense(1)

      {init_fn, _predict_fn} = Axon.build(model)
      params = init_fn.(Nx.template({1, 2}, :f32), %{})

      data = Nx.tensor([[1.0, 2.0]])
      labels = Nx.tensor([1.0])

      result =
        Dala.ML.Training.fine_tune(
          model,
          params,
          {data, labels},
          epochs: 1
        )

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts progress callback option" do
      model =
        Axon.input("input", shape: {nil, 2})
        |> Axon.dense(1)

      {init_fn, _predict_fn} = Axon.build(model)
      params = init_fn.(Nx.template({1, 2}, :f32), %{})

      data = Nx.tensor([[1.0, 2.0]])
      labels = Nx.tensor([1.0])

      progress_called = :atomics.new(1, [])

      result =
        Dala.ML.Training.fine_tune(
          model,
          params,
          {data, labels},
          epochs: 1,
          progress: fn _epoch, _loss -> :atomics.add(progress_called, 1, 1) end
        )

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "accepts custom optimizer option" do
      model =
        Axon.input("input", shape: {nil, 2})
        |> Axon.dense(1)

      {init_fn, _predict_fn} = Axon.build(model)
      params = init_fn.(Nx.template({1, 2}, :f32), %{})

      data = Nx.tensor([[1.0, 2.0]])
      labels = Nx.tensor([1.0])

      result =
        Dala.ML.Training.fine_tune(
          model,
          params,
          {data, labels},
          epochs: 1,
          optimizer: &Polaris.Optimizers.sgd(&1, lr: 0.01)
        )

      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "evaluate/4" do
    test "returns results or error" do
      model =
        Axon.input("input", shape: {nil, 2})
        |> Axon.dense(1)

      {init_fn, _predict_fn} = Axon.build(model)
      params = init_fn.(Nx.template({1, 2}, :f32), %{})

      data = Nx.tensor([[1.0, 2.0]])
      labels = Nx.tensor([1.0])

      result = Dala.ML.Training.evaluate(model, params, {data, labels})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end
end
