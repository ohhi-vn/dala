defmodule Dala.Storage.Storage do
  @moduledoc """
  App-local file storage.

  Provides a thin Elixir wrapper over the device filesystem using named
  locations instead of raw paths. Basic file operations (`list`, `stat`,
  `delete`, `copy`, `move`, `read`, `write`) are pure `File.*` calls —
  no NIF overhead except for the initial `dir/1` path resolution.

  ## Locations

    - `:temp`        — ephemeral; may be purged by the OS at any time
    - `:documents`   — persists across app sessions; user-visible on iOS
                       when `UIFileSharingEnabled` is set (see `mix dala.enable`)
    - `:cache`       — persists until OS needs space; not user-visible
    - `:app_support` — persists, hidden from user, backed up on iOS

  ## Platform-specific storage

  See `Dala.Storage.Apple` and `Dala.Storage.Android` for saving to the native
  photo/media library and accessing platform-specific directories.

  ## Results

  Operations that can fail return `{:ok, value} | {:error, posix}`.
  `dir/1` raises on an unknown location atom.
  """

  @locations [:temp, :documents, :cache, :app_support]

  @compile {:nowarn_undefined, [:Nx]}

  @doc "Resolve a location atom to its absolute path on the current device."
  @spec dir(atom()) :: String.t()
  def dir(location) when location in @locations do
    Dala.Platform.Native.storage_dir(location) |> IO.iodata_to_binary()
  end

  @doc """
  List all files in a location or an absolute path.

  Returns full paths, not just names.
  """
  @spec list(atom() | String.t()) :: {:ok, [String.t()]} | {:error, atom()}
  def list(location) when is_atom(location), do: list(dir(location))

  def list(path) when is_binary(path) do
    case File.ls(path) do
      {:ok, names} -> {:ok, Enum.map(names, &Path.join(path, &1))}
      error -> error
    end
  end

  @doc """
  Return metadata for a file.

      %{name: "clip.mp4", path: "/…/clip.mp4", size: 204_800,
        modified_at: ~U[2026-04-24 10:00:00Z]}
  """
  @spec stat(String.t()) :: {:ok, map()} | {:error, atom()}
  def stat(path) do
    case File.stat(path, time: :posix) do
      {:ok, %File.Stat{size: size, mtime: mtime}} ->
        {:ok,
         %{
           name: Path.basename(path),
           path: path,
           size: size,
           modified_at: DateTime.from_unix!(mtime)
         }}

      error ->
        error
    end
  end

  @doc """
  Delete a file or directory at `path`.

  Use `force: true` to delete non-empty directories.
  Returns `:ok` on success.

      Dala.Storage.delete("/tmp/old_file.txt")
      Dala.Storage.delete("/tmp/old_dir", force: true)
  """
  @spec delete(String.t(), keyword()) :: :ok | {:error, atom()}
  def delete(path, opts \\ []) do
    case Keyword.get(opts, :force, false) do
      true ->
        case File.rm_rf(path) do
          {:ok, _} -> :ok
          error -> error
        end

      false ->
        File.rm(path)
    end
  end

  @doc """
  Copy `src` to `dest`.

  `dest` may be a location atom (file is placed there keeping its basename)
  or a full absolute path.

  Returns `{:ok, dest_path}` on success.
  """
  @spec copy(String.t(), atom() | String.t()) :: {:ok, String.t()} | {:error, atom()}
  def copy(src, dest) when is_atom(dest) do
    copy(src, Path.join(dir(dest), Path.basename(src)))
  end

  def copy(src, dest) when is_binary(dest) do
    with :ok <- File.cp(src, dest), do: {:ok, dest}
  end

  @doc """
  Move `src` to `dest`.

  `dest` may be a location atom (file is placed there keeping its basename)
  or a full absolute path. Creates parent directories of `dest` if needed.

  Returns `{:ok, dest_path}` on success.

      Dala.Storage.move("/tmp/old.txt", "/tmp/new.txt")
      Dala.Storage.move("/tmp/file.txt", :documents)
  """
  @spec move(String.t(), atom() | String.t()) :: {:ok, String.t()} | {:error, atom()}
  def move(src, dest) when is_atom(dest) do
    move(src, Path.join(dir(dest), Path.basename(src)))
  end

  def move(src, dest) when is_binary(dest) do
    with :ok <- File.mkdir_p(Path.dirname(dest)),
         :ok <- File.rename(src, dest),
         do: {:ok, dest}
  end

  @doc "Read a file's contents as a binary."
  @spec read(String.t()) :: {:ok, binary()} | {:error, atom()}
  def read(path), do: File.read(path)

  @doc """
  Write `data` to `path`.

  Returns `{:ok, path}` on success.
  """
  @spec write(String.t(), binary()) :: {:ok, String.t()} | {:error, atom()}
  def write(path, data) do
    with :ok <- File.write(path, data), do: {:ok, path}
  end

  @doc """
  Return the file extension including the leading dot, or `""` if none.

  No I/O — derived from the filename only.

      Dala.Storage.extension("/tmp/clip.mp4")   #=> ".mp4"
      Dala.Storage.extension("/tmp/notes")      #=> ""
  """
  @spec extension(String.t()) :: String.t()
  def extension(path), do: Path.extname(path)

  @doc """
  Create a new empty file at `path`.

  Creates parent directories if they don't exist.
  Returns `{:ok, path}` on success.

      Dala.Storage.create("/tmp/new_file.txt")
  """
  @spec create(String.t()) :: {:ok, String.t()} | {:error, atom()}
  def create(path) do
    with :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.touch(path),
         do: {:ok, path}
  end

  @doc """
  Create a new file at `path` with the given `content`.

  Creates parent directories if they don't exist.
  Returns `{:ok, path}` on success.

      Dala.Storage.create("/tmp/new_file.txt", "Hello, World!")
  """
  @spec create(String.t(), binary()) :: {:ok, String.t()} | {:error, atom()}
  def create(path, content) when is_binary(content) do
    with :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(path, content),
         do: {:ok, path}
  end

  @doc """
  Update the contents of an existing file at `path`.

  Returns `{:ok, path}` on success. Returns `{:error, :enoent}` if the file
  doesn't exist.

      Dala.Storage.update("/tmp/existing_file.txt", "Updated content")
  """
  @spec update(String.t(), binary()) :: {:ok, String.t()} | {:error, atom()}
  def update(path, content) when is_binary(content) do
    case File.exists?(path) do
      true ->
        with :ok <- File.write(path, content), do: {:ok, path}

      false ->
        {:error, :enoent}
    end
  end

  @doc """
  Export a file from a location to a destination path.

  Creates parent directories of `dest` if needed.
  Returns `{:ok, dest_path}` on success.

      Dala.Storage.export("/tmp/file.txt", "/tmp/backup/file.txt")
  """
  @spec export(String.t(), String.t()) :: {:ok, String.t()} | {:error, atom()}
  def export(src, dest) when is_binary(dest) do
    with :ok <- File.mkdir_p(Path.dirname(dest)),
         :ok <- File.cp(src, dest),
         do: {:ok, dest}
  end

  @doc """
  Return detailed file information.

  Returns a map with `:name`, `:path`, `:size`, `:modified_at`, `:type`,
  and `:extension`.

      Dala.Storage.info("/tmp/clip.mp4")
      #=> %{name: "clip.mp4", path: "/tmp/clip.mp4", size: 204800,
      #    modified_at: ~U[2026-04-24 10:00:00Z], type: :regular,
      #    extension: ".mp4"}
  """
  @spec info(String.t()) :: {:ok, map()} | {:error, atom()}
  def info(path) do
    case File.stat(path, time: :posix) do
      {:ok, %File.Stat{size: size, mtime: mtime, type: type}} ->
        {:ok,
         %{
           name: Path.basename(path),
           path: path,
           size: size,
           modified_at: DateTime.from_unix!(mtime),
           type: type,
           extension: Path.extname(path)
         }}

      error ->
        error
    end
  end

  @doc """
  Check if a file or directory exists at `path`.

      Dala.Storage.exists?("/tmp/file.txt")  #=> true
  """
  @spec exists?(String.t()) :: boolean()
  def exists?(path), do: File.exists?(path)

  @doc """
  Ensure the parent directory for `path` exists, creating it if necessary.

  Returns `:ok` on success.

      Dala.Storage.ensure_dir("/tmp/new_dir/file.txt")
  """
  @spec ensure_dir(String.t()) :: :ok | {:error, atom()}
  def ensure_dir(path), do: File.mkdir_p(Path.dirname(path))

  @doc """
  Return the file size in bytes, or `{:error, reason}` if the file doesn't exist.

      Dala.Storage.size("/tmp/file.txt")  #=> {:ok, 1024}
  """
  @spec size(String.t()) :: {:ok, non_neg_integer()} | {:error, atom()}
  def size(path) do
    case File.stat(path) do
      {:ok, %File.Stat{size: size}} -> {:ok, size}
      error -> error
    end
  end

  @doc """
  Append `data` to the end of a file.

  Creates the file if it doesn't exist.
  Returns `{:ok, path}` on success.

      Dala.Storage.append("/tmp/log.txt", "New log entry\\n")
  """
  @spec append(String.t(), binary()) :: {:ok, String.t()} | {:error, atom()}
  def append(path, data) when is_binary(data) do
    with :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(path, data, [:append]),
         do: {:ok, path}
  end

  @doc """
  Read a file and return its contents as a string.

  Returns `{:ok, content}` on success.

      Dala.Storage.read_text("/tmp/file.txt")  #=> {:ok, "Hello"}
  """
  @spec read_text(String.t()) :: {:ok, String.t()} | {:error, atom()}
  def read_text(path), do: File.read(path)

  @doc """
  Write `content` to a file as text.

  Creates parent directories if they don't exist.
  Returns `{:ok, path}` on success.

      Dala.Storage.write_text("/tmp/file.txt", "Hello, World!")
  """
  @spec write_text(String.t(), String.t()) :: {:ok, String.t()} | {:error, atom()}
  def write_text(path, content) when is_binary(content) do
    with :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(path, content),
         do: {:ok, path}
  end
end
