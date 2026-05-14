defmodule Dala.ML.Model do
  @moduledoc """
  Model management for Dala ML.

  Handles model download, caching, compilation, and versioning.
  Models are stored in the app's private directory and can be
  hot-swapped without app restart.

  ## Usage

      # Download a model from URL
      {:ok, model_info} = Dala.ML.Model.download("https://example.com/model.mlmodel")

      # List cached models
      models = Dala.ML.Model.cached_models()

      # Get model path for loading
      path = Dala.ML.Model.path("my_model")

      # Delete a cached model
      :ok = Dala.ML.Model.delete("my_model")
  """

  @models_dir "ml_models"

  @doc """
  Returns the directory where models are cached.
  """
  @spec cache_dir() :: String.t()
  def cache_dir do
    dir = Path.join([:code.priv_dir(:dala), @models_dir])
    File.mkdir_p!(dir)
    dir
  end

  @doc """
  Downloads a model from a URL and caches it locally.

  ## Options

  - `:name` — Custom name for the model (defaults to filename from URL)
  - `:checksum` — Expected SHA256 checksum for verification
  - `:force` — Overwrite existing cached model (default: false)
  """
  @spec download(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def download(url, opts \\ []) do
    name = Keyword.get(opts, :name, filename_from_url(url))
    dest = Path.join(cache_dir(), name)

    if File.exists?(dest) and not Keyword.get(opts, :force, false) do
      {:ok, %{name: name, path: dest, cached: true}}
    else
      case http_get(url) do
        {:ok, data} ->
          if checksum_valid?(data, opts[:checksum]) do
            File.write!(dest, data)
            {:ok, %{name: name, path: dest, size: byte_size(data), cached: false}}
          else
            {:error, "Checksum mismatch"}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Returns a list of cached model info maps.
  """
  @spec cached_models() :: [map()]
  def cached_models do
    cache_dir()
    |> File.ls!()
    |> Enum.map(fn name ->
      path = Path.join(cache_dir(), name)
      stat = File.stat!(path)

      %{
        name: name,
        path: path,
        size: stat.size,
        modified: stat.mtime
      }
    end)
  end

  @doc """
  Returns the local path for a cached model by name.
  """
  @spec path(String.t()) :: String.t() | nil
  def path(name) do
    p = Path.join(cache_dir(), name)
    if File.exists?(p), do: p, else: nil
  end

  @doc """
  Deletes a cached model.
  """
  @spec delete(String.t()) :: :ok | {:error, term()}
  def delete(name) do
    case path(name) do
      nil -> {:error, "Model not found: #{name}"}
      p -> File.rm(p)
    end
  end

  @doc """
  Clears all cached models.
  """
  @spec clear_cache() :: :ok
  def clear_cache do
    cache_dir()
    |> File.ls!()
    |> Enum.each(&File.rm(Path.join(cache_dir(), &1)))

    :ok
  end

  @doc """
  Returns the total size of all cached models in bytes.
  """
  @spec cache_size() :: non_neg_integer()
  def cache_size do
    cached_models()
    |> Enum.map(& &1.size)
    |> Enum.sum()
  end

  @doc """
  Compiles a CoreML model (.mlmodel → .mlmodelc) for faster loading.

  Only relevant on iOS. On other platforms, returns the path unchanged.
  """
  @spec compile(String.t()) :: {:ok, String.t()} | {:error, term()}
  def compile(model_path) do
    if Dala.ML.ios?() do
      compiled = model_path <> "c"

      case System.cmd("xcrun", ["coremlc", "compile", model_path, compiled]) do
        {_, 0} -> {:ok, compiled}
        {err, _} -> {:error, "CoreML compilation failed: #{err}"}
      end
    else
      {:ok, model_path}
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp filename_from_url(url) do
    uri = URI.parse(url)
    Path.basename(uri.path) || "model_#{:erlang.unique_integer([:positive])}"
  end

  defp http_get(url) do
    case :httpc.request(:get, {String.to_charlist(url), []}, [], []) do
      {:ok, {{_, 200, _}, _, body}} ->
        {:ok, :erlang.list_to_binary(body)}

      {:ok, {{_, status, _}, _, _}} ->
        {:error, "HTTP #{status}"}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
  end

  defp checksum_valid?(_data, nil), do: true

  defp checksum_valid?(data, expected) do
    actual = :crypto.hash(:sha256, data) |> Base.encode16(case: :lower)
    actual == String.downcase(expected)
  end
end
