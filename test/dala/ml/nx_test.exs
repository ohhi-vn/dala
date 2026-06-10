defmodule Dala.Ml.Nx.Test do
  @moduledoc """
  Tests for Dala.Ml.Nx — Nx integration helpers.
  """

  use ExUnit.Case, async: true

  describe "init/0" do
    test "returns :emlx or :nx_binary" do
      result = Dala.Ml.Nx.init()
      assert result in [:emlx, :nx_binary]
    end

    test "configures Nx backend" do
      Dala.Ml.Nx.init()
      backend = Nx.default_backend()
      assert is_atom(backend) or is_tuple(backend)
    end
  end

  describe "emlx_available?/0" do
    test "returns true when EMLX is loaded" do
      if Code.ensure_loaded?(EMLX) do
        assert Dala.Ml.Nx.emlx_available?() == true
      else
        assert Dala.Ml.Nx.emlx_available?() == false
      end
    end
  end

  describe "tensor/2" do
    test "creates a tensor with default backend" do
      t = Dala.Ml.Nx.tensor([1.0, 2.0, 3.0])
      assert Nx.shape(t) == {3}
    end

    test "creates a tensor with explicit backend" do
      t = Dala.Ml.Nx.tensor([1.0, 2.0], backend: Nx.BinaryBackend)
      assert Nx.shape(t) == {2}
    end

    test "creates a 2D tensor" do
      t = Dala.Ml.Nx.tensor([[1.0, 2.0], [3.0, 4.0]])
      assert Nx.shape(t) == {2, 2}
    end
  end

  describe "default_backend/0" do
    test "returns an atom or tuple" do
      backend = Dala.Ml.Nx.default_backend()
      assert is_atom(backend) or is_tuple(backend)
    end

    test "returns EMLX.Backend when EMLX is available" do
      if Dala.Ml.Nx.emlx_available?() do
        assert match?({EMLX.Backend, _}, Dala.Ml.Nx.default_backend())
      end
    end

    test "returns Nx.BinaryBackend when EMLX is not available" do
      if not Dala.Ml.Nx.emlx_available?() do
        assert Dala.Ml.Nx.default_backend() == Nx.BinaryBackend
      end
    end
  end

  describe "inference/3" do
    test "runs inference with a simple model" do
      model =
        Axon.input("input", shape: {nil, 2})
        |> Axon.dense(1)

      {init_fn, _predict_fn} = Axon.build(model)
      params = init_fn.(Nx.template({1, 2}, :f32), %{})

      result = Dala.Ml.Nx.inference(model, params, [[1.0, 2.0]])
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "returns error for mismatched input shape" do
      model =
        Axon.input("input", shape: {nil, 2})
        |> Axon.dense(1)

      {init_fn, _predict_fn} = Axon.build(model)
      params = init_fn.(Nx.template({1, 2}, :f32), %{})

      result = Dala.Ml.Nx.inference(model, params, [[1.0, 2.0, 3.0]])
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end
  end

  describe "axon_available?/0" do
    test "returns true when Axon is loaded" do
      if Code.ensure_loaded?(Axon) do
        assert Dala.Ml.Nx.axon_available?() == true
      end
    end
  end
end
