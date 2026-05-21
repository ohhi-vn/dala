defmodule MlModelsApp.OnnxRuntime do
  @moduledoc """
  ONNX model download, cache, and inference helper.

  Downloads models from HuggingFace, caches to priv/models/,
  and provides high-level predict functions for sentiment analysis
  and object detection.
  """

  # Logger not needed — using Dala.Platform.Native.log/1 for on-device logging

  @models %{
    sentiment: %{
      name: "distilbert-sst2",
      display: "Sentiment Analysis",
      url:
        "https://huggingface.co/distilbert/distilbert-base-uncased-finetuned-sst-2-english/resolve/main/onnx/model.onnx",
      file: "model_sentiment.onnx",
      labels: ["NEGATIVE", "POSITIVE"]
    },
    detection: %{
      name: "yolos-tiny",
      display: "Object Detection",
      url: "https://huggingface.co/Xenova/yolos-tiny/resolve/main/onnx/model.onnx",
      file: "model_detection.onnx",
      labels: nil
    }
  }

  @doc "Return the model registry map."
  @spec models :: map()
  def models, do: @models

  @doc "Return the path where models are cached."
  @spec cache_dir :: String.t()
  def cache_dir do
    dir = Path.join(:code.priv_dir(:ml_models_app), "models")
    File.mkdir_p!(dir)
    dir
  end

  @doc "Return the local path for a model file."
  @spec model_path(atom()) :: String.t()
  def model_path(model_key) do
    model = Map.fetch!(@models, model_key)
    Path.join(cache_dir(), model.file)
  end

  @doc "Check if a model file is cached locally."
  @spec cached?(atom()) :: boolean()
  def cached?(model_key) do
    model_path(model_key) |> File.exists?()
  end

  @doc "Download a model from HuggingFace with progress tracking."
  @spec download(atom(), (non_neg_integer() -> :ok)) :: {:ok, String.t()} | {:error, term()}
  def download(model_key, _progress_callback \\ fn _ -> :ok end) do
    model = Map.fetch!(@models, model_key)
    dest = model_path(model_key)

    if cached?(model_key) do
      {:ok, dest}
    else
      Dala.Platform.Native.log("OnnxRuntime: downloading #{model.display}...")

      case Req.get(model.url, receive_timeout: 120_000) do
        {:ok, %{status: 200, body: body}} ->
          File.write!(dest, body)
          size_mb = Float.round(byte_size(body) / 1_048_576, 1)
          Dala.Platform.Native.log("OnnxRuntime: #{model.display} downloaded (#{size_mb} MB)")
          {:ok, dest}

        {:ok, %{status: status}} ->
          {:error, "HTTP #{status}"}

        {:error, reason} ->
          {:error, inspect(reason)}
      end
    end
  end

  @doc "Load a model into ONNX Runtime. Returns {:ok, model_ref} or {:error, reason}."
  @spec load_model(atom()) :: {:ok, integer()} | {:error, term()}
  def load_model(model_key) do
    path = model_path(model_key)

    unless File.exists?(path) do
      {:error, "Model not cached: #{model_key}. Download first."}
    end

    case Dala.ML.ONNX.load_model(path, ep: :cpu) do
      {:ok, model_ref} ->
        {:ok, model_ref}

      {:error, reason} ->
        {:error, "Failed to load #{model_key}: #{inspect(reason)}"}
    end
  end

  @doc """
  Run sentiment analysis on text.

  Returns {:ok, %{label: "POSITIVE" | "NEGATIVE", confidence: float}}.
  """
  @spec predict_sentiment(integer(), String.t()) :: {:ok, map()} | {:error, term()}
  def predict_sentiment(model_ref, text) when is_integer(model_ref) do
    # Tokenize: simple word-piece tokenization for DistilBERT
    input_ids = tokenize(text)
    input_tensor = Nx.tensor([input_ids], type: {:s, 64})
    attention_mask = Nx.tensor([List.duplicate(1, length(input_ids))], type: {:s, 64})

    case Dala.ML.ONNX.predict(model_ref, %{
           "input_ids" => input_tensor,
           "attention_mask" => attention_mask
         }) do
      {:ok, %{"logits" => logits}} ->
        interpret_sentiment(logits)

      {:ok, outputs} ->
        # Try common output names
        logits =
          Map.get(outputs, "logits") ||
            Map.get(outputs, "output") ||
            Map.get(outputs, Enum.at(Map.keys(outputs), 0))

        if logits, do: interpret_sentiment(logits), else: {:error, "Unexpected output format"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Run object detection on an image.

  Returns {:ok, [%{label: String.t(), confidence: float, bbox: [float]}]}.
  """
  @spec predict_detection(integer(), String.t()) :: {:ok, list()} | {:error, term()}
  def predict_detection(model_ref, image_path) when is_integer(model_ref) do
    case load_image_tensor(image_path) do
      {:ok, tensor} ->
        case Dala.ML.ONNX.predict(model_ref, %{"pixel_values" => tensor}) do
          {:ok, outputs} ->
            interpret_detection(outputs)

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Unload an ONNX model and free resources."
  @spec unload(integer()) :: :ok | {:error, term()}
  def unload(model_ref) when is_integer(model_ref) do
    Dala.ML.ONNX.unload(model_ref)
  end

  # ── Tokenization ───────────────────────────────────────────────────────

  # Simple whitespace + punctuation tokenizer for DistilBERT.
  # Maps tokens to IDs using a basic hash since we don't ship the full vocab.
  # For production, use the tokenizer.json from HuggingFace.
  defp tokenize(text) do
    text
    |> String.downcase()
    |> String.split(~r/[\s[:punct:]]+/, trim: true)
    |> Enum.map(&word_to_id/1)
    |> pad_or_truncate(128)
  end

  defp word_to_id(token) do
    # Simple hash-based token ID — not accurate for real inference
    # but demonstrates the pipeline. Replace with real vocab lookup.
    :erlang.phash2(token, 30_522)
  end

  defp pad_or_truncate(ids, max_len) do
    cond do
      length(ids) >= max_len -> Enum.take(ids, max_len)
      true -> ids ++ List.duplicate(0, max_len - length(ids))
    end
  end

  # ── Output interpretation ──────────────────────────────────────────────

  defp interpret_sentiment(logits) do
    # Apply softmax to logits
    flat = Nx.to_flat_list(logits)

    # Handle 2D logits [batch, 2]
    scores =
      case flat do
        [neg, pos] -> [neg, pos]
        _ -> Enum.take(flat, 2)
      end

    [neg, pos] = softmax(scores)
    labels = ["NEGATIVE", "POSITIVE"]

    if pos >= neg do
      {:ok, %{label: Enum.at(labels, 1), confidence: Float.round(pos, 4)}}
    else
      {:ok, %{label: Enum.at(labels, 0), confidence: Float.round(neg, 4)}}
    end
  end

  defp softmax(values) do
    max_val = Enum.max(values)
    exps = Enum.map(values, fn v -> :math.exp(v - max_val) end)
    sum = Enum.sum(exps)
    Enum.map(exps, fn e -> e / sum end)
  end

  defp interpret_detection(outputs) do
    logits = Map.get(outputs, "logits") || Map.get(outputs, "output")

    if logits do
      # Simplified: return raw output shapes for demonstration
      shape = Nx.shape(logits)

      {:ok,
       [
         %{
           label: "detected_objects",
           confidence: 0.0,
           bbox: [0, 0, 0, 0],
           note: "Raw output shape: #{inspect(shape)}"
         }
       ]}
    else
      {:ok, [%{label: "no_detections", confidence: 0.0, bbox: [0, 0, 0, 0]}]}
    end
  end

  # ── Image loading ──────────────────────────────────────────────────────

  defp load_image_tensor(image_path) do
    # Load image and convert to tensor [1, 3, H, W]
    # For demo purposes, create a placeholder tensor
    # In production, use ImageMagick or similar to load and resize
    if File.exists?(image_path) do
      # Placeholder: 3x224x224 normalized tensor
      tensor = Nx.random_uniform({1, 3, 224, 224}, type: {:f, 32})
      {:ok, tensor}
    else
      {:error, "Image not found: #{image_path}"}
    end
  end
end
