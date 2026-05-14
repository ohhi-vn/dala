defmodule Dala.ML.Preprocess.Test do
  @moduledoc """
  Tests for Dala.ML.Preprocess — image, audio, and tensor preprocessing.
  """

  use ExUnit.Case, async: true

  describe "to_batch/1" do
    test "adds batch dimension to 1D tensor" do
      tensor = Nx.tensor([1.0, 2.0, 3.0])
      batched = Dala.ML.Preprocess.to_batch(tensor)
      assert Nx.shape(batched) == {1, 3}
    end

    test "adds batch dimension to 2D tensor" do
      tensor = Nx.tensor([[1.0, 2.0], [3.0, 4.0]])
      batched = Dala.ML.Preprocess.to_batch(tensor)
      assert Nx.shape(batched) == {1, 2, 2}
    end

    test "adds batch dimension to 3D tensor" do
      tensor = Nx.tensor([[[1.0, 2.0], [3.0, 4.0]]])
      batched = Dala.ML.Preprocess.to_batch(tensor)
      assert Nx.shape(batched) == {1, 1, 2, 2}
    end

    test "preserves values" do
      tensor = Nx.tensor([1.0, 2.0, 3.0])
      batched = Dala.ML.Preprocess.to_batch(tensor)
      assert Nx.to_flat_list(batched) == [1.0, 2.0, 3.0]
    end
  end

  describe "normalize/2" do
    test "imagenet normalization" do
      # Create a 1x1x3 tensor with value 255 (max)
      tensor = Nx.tensor([[[255, 255, 255]]], type: :u8)
      result = Dala.ML.Preprocess.normalize(tensor, :imagenet)

      # After imagenet norm: (255/255 - mean) / std
      # Should be approximately (1.0 - 0.485) / 0.229 ≈ 2.248 for R channel
      assert Nx.shape(result) == {1, 1, 3}
    end

    test "minmax normalization scales to [0, 1]" do
      tensor = Nx.tensor([0.0, 50.0, 100.0])
      result = Dala.ML.Preprocess.normalize(tensor, :minmax)

      flat = Nx.to_flat_list(result)
      assert Enum.min(flat) >= 0.0
      assert Enum.max(flat) <= 1.0
    end

    test "standard normalization produces zero mean" do
      tensor = Nx.tensor([1.0, 2.0, 3.0, 4.0, 5.0])
      result = Dala.ML.Preprocess.normalize(tensor, :standard)

      mean = Nx.mean(result) |> Nx.to_number()
      assert abs(mean) < 1.0e-6
    end

    test "custom normalization with {mean, std}" do
      tensor = Nx.tensor([10.0, 20.0, 30.0])
      result = Dala.ML.Preprocess.normalize(tensor, {[10.0, 10.0, 10.0], [5.0, 5.0, 5.0]})

      assert Nx.shape(result) == {3}
    end
  end

  describe "to_f32_binary/1" do
    test "converts tensor to f32 binary" do
      tensor = Nx.tensor([1.0, 2.0, 3.0])
      binary = Dala.ML.Preprocess.to_f32_binary(tensor)

      assert is_binary(binary)
      # 3 f32 values = 12 bytes
      assert byte_size(binary) == 12
    end

    test "preserves values" do
      tensor = Nx.tensor([1.0, 2.0, 3.0])
      binary = Dala.ML.Preprocess.to_f32_binary(tensor)
      restored = Nx.from_binary(binary, :f32)
      assert Nx.to_flat_list(restored) == [1.0, 2.0, 3.0]
    end
  end

  describe "resize/2" do
    test "returns same tensor when shape matches" do
      # {1, 1, 3}
      tensor = Nx.tensor([[[1.0, 2.0, 3.0]]])
      result = Dala.ML.Preprocess.resize(tensor, {1, 1})
      assert Nx.shape(result) == {1, 1, 3}
    end

    test "returns tensor with target dimensions" do
      # {1, 2, 3}
      tensor = Nx.tensor([[[1.0, 2.0, 3.0], [4.0, 5.0, 6.0]]])
      result = Dala.ML.Preprocess.resize(tensor, {1, 2})
      assert Nx.shape(result) == {1, 2, 3}
    end
  end

  describe "load_image/1" do
    test "returns error for non-existent file" do
      result = Dala.ML.Preprocess.load_image("/non/existent/image.png")
      assert match?({:error, _}, result)
    end

    test "returns tuple result" do
      result = Dala.ML.Preprocess.load_image("/non/existent/image.png")
      assert is_tuple(result)
    end
  end

  describe "load_audio/1" do
    test "returns error for non-existent file" do
      result = Dala.ML.Preprocess.load_audio("/non/existent/audio.wav")
      assert match?({:error, _}, result)
    end

    test "returns tuple result" do
      result = Dala.ML.Preprocess.load_audio("/non/existent/audio.wav")
      assert is_tuple(result)
    end
  end

  describe "mel_spectrogram/2" do
    test "accepts audio tensor" do
      samples = Nx.tensor([0.1, 0.2, 0.3, 0.4, 0.5])
      result = Dala.ML.Preprocess.mel_spectrogram(samples)
      assert match?({:ok, _}, result) or is_struct(result, Nx.Tensor)
    end

    test "accepts options" do
      samples = Nx.tensor([0.1, 0.2, 0.3, 0.4, 0.5])
      result = Dala.ML.Preprocess.mel_spectrogram(samples, sample_rate: 16000, n_mels: 80)
      assert match?({:ok, _}, result) or is_struct(result, Nx.Tensor)
    end
  end

  describe "full image pipeline" do
    test "to_batch → normalize → to_f32_binary" do
      tensor = Nx.tensor([[[128, 128, 128]]], type: :u8)

      result =
        tensor
        |> Dala.ML.Preprocess.to_batch()
        |> Dala.ML.Preprocess.normalize(:imagenet)
        |> Dala.ML.Preprocess.to_f32_binary()

      assert is_binary(result)
    end
  end
end
