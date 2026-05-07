defmodule Dala.ML.Example do
  @compile {:nowarn_undefined, [:Nx]}
  @moduledoc """
  Simple example of using ML in a Dala app.

  This module demonstrates basic ML operations using the
  auto-configured backend (EMLX on iOS, BinaryBackend elsewhere).
  """

  @doc """
  Simple tensor operations with auto-configured backend.

  Run this in a Dala app after calling `Dala.ML.setup/0`.
  """
  def basic_operations do
    Dala.ML.Nx.init()

    a = Nx.tensor([[1.0, 2.0], [3.0, 4.0]])
    b = Nx.tensor([[5.0], [6.0]])
    result = Nx.dot(a, b)

    %{
      input_a: Nx.to_flat_list(a),
      input_b: Nx.to_flat_list(b),
      result: Nx.to_flat_list(result),
      backend: inspect(Nx.default_backend())
    }
  end

  @doc """
  Image classification using a quantized dalaileNet model.
  """
  def image_classify(image_tensor, _model_path \\ "dalailenet_v2_quantized") do
    _input =
      image_tensor
      |> Nx.reshape({224, 224, 3})
      |> Nx.divide(255.0)
      |> Nx.subtract(0.5)
      |> Nx.multiply(2.0)
      |> Nx.reshape({1, 224, 224, 3})

    key = Nx.Random.key(42)
    {output, _key} = Nx.Random.uniform(key, {1, 1000})

    %{
      predicted_class: Nx.argmax(output) |> Nx.to_number(),
      confidence: Nx.reduce_max(output) |> Nx.to_number(),
      backend: inspect(Nx.default_backend()),
      note: "Load actual quantized model for production"
    }
  end

  @doc """
  Simplified YOLO-like object detection.
  """
  def yolo_detect(image_tensor, _model_path \\ "yolo_nano_quantized") do
    _input =
      image_tensor
      |> Nx.reshape({416, 416, 3})
      |> Nx.divide(255.0)
      |> Nx.reshape({1, 416, 416, 3})

    detection_output =
      Nx.Random.uniform(Nx.Random.key(42), {1, 13, 13, 18})

    %{
      output_shape: Nx.shape(detection_output),
      backend: inspect(Nx.default_backend()),
      note: "Use real YOLO model for production detection"
    }
  end

  @doc """
  Load a pre-trained quantized model for iOS.
  """
  def load_quantized_model(model_name) when is_binary(model_name) do
    %{
      model_name: model_name,
      status: :placeholder,
      suggested_models: [
        "dalailenet_v2_quantized",
        "yolo_nano_quantized",
        "efficientnet_lite_quantized"
      ]
    }
  end

  @doc """
  Verify EMLX is working on iOS.
  """
  def verify_setup do
    case Dala.ML.EMLX.available?() do
      true ->
        result = basic_operations()
        {:ok, result}

      false ->
        {:error, "EMLX not available. Check that :emlx is in your deps."}
    end
  end
end
