# File Storage

Dala provides a file storage API for reading, writing, and managing files on-device. All operations use named locations instead of raw paths, so your code works identically on iOS and Android.

## Locations

| Location | Persistence | User-visible | Backup |
|----------|-------------|--------------|--------|
| `:temp` | Ephemeral; may be purged by OS | No | No |
| `:documents` | Persists across sessions | iOS: yes (with `UIFileSharingEnabled`) | Yes |
| `:cache` | Persists until OS needs space | No | No |
| `:app_support` | Persists, hidden from user | No | Yes |

Resolve a location to its absolute path:

```elixir
Dala.Storage.dir(:documents)
#=> "/data/data/com.example.app/Documents"   (Android)
#=> "/var/mobile/Containers/Data/Application/.../Documents"  (iOS)
```

## Basic Operations

### Create files

```elixir
# Create empty file (creates parent directories)
{:ok, path} = Dala.Storage.create("/tmp/new_file.txt")

# Create file with content
{:ok, path} = Dala.Storage.create("/tmp/hello.txt", "Hello, World!")
```

### Read and write

```elixir
# Read file contents
{:ok, content} = Dala.Storage.read("/tmp/hello.txt")
{:ok, text} = Dala.Storage.read_text("/tmp/hello.txt")

# Write file contents
{:ok, path} = Dala.Storage.write("/tmp/data.bin", <<1, 2, 3>>)
{:ok, path} = Dala.Storage.write_text("/tmp/hello.txt", "Hello!")

# Append to file (creates if missing)
{:ok, path} = Dala.Storage.append("/tmp/log.txt", "New entry\n")
```

### Update existing files

```elixir
# Update returns {:error, :enoent} if file doesn't exist
{:ok, path} = Dala.Storage.update("/tmp/existing.txt", "New content")
{:error, :enoent} = Dala.Storage.update("/tmp/missing.txt", "Content")
```

### Delete files

```elixir
# Delete file
:ok = Dala.Storage.delete("/tmp/old.txt")

# Delete non-empty directory
:ok = Dala.Storage.delete("/tmp/old_dir", force: true)
```

### Move and copy

```elixir
# Move to absolute path
{:ok, dest} = Dala.Storage.move("/tmp/old.txt", "/tmp/new.txt")

# Move to location (keeps original filename)
{:ok, dest} = Dala.Storage.move("/tmp/file.txt", :documents)

# Copy file
{:ok, dest} = Dala.Storage.copy("/tmp/file.txt", :cache)

# Export to destination (creates parent dirs)
{:ok, dest} = Dala.Storage.export("/tmp/file.txt", "/tmp/backup/file.txt")
```

## File Information

```elixir
# Get file info
{:ok, info} = Dala.Storage.info("/tmp/clip.mp4")
#=> %{
#   name: "clip.mp4",
#   path: "/tmp/clip.mp4",
#   size: 204800,
#   modified_at: ~U[2026-04-24 10:00:00Z],
#   type: :regular,
#   extension: ".mp4"
# }

# Quick checks
true = Dala.Storage.exists?("/tmp/file.txt")
{:ok, 1024} = Dala.Storage.size("/tmp/file.txt")
".mp4" = Dala.Storage.extension("/tmp/clip.mp4")
```

## Listing and querying

```elixir
# List files in a location
{:ok, files} = Dala.Storage.list(:documents)
#=> ["/data/data/com.example.app/Documents/notes.txt", ...]

# List files in a directory
{:ok, files} = Dala.Storage.list("/tmp")

# Get file metadata (legacy API)
{:ok, stat} = Dala.Storage.stat("/tmp/file.txt")
#=> %{name: "file.txt", path: "/tmp/file.txt", size: 1024, modified_at: ~U[...]}
```

## Directory management

```elixir
# Ensure parent directories exist
:ok = Dala.Storage.ensure_dir("/tmp/new_dir/file.txt")
```

## Working with locations

All functions that accept a path also accept a location atom:

```elixir
# These are equivalent:
Dala.Storage.list(:documents)
Dala.Storage.list(Dala.Storage.dir(:documents))

# Move to location resolves path automatically:
Dala.Storage.move("/tmp/file.txt", :documents)
# equivalent to:
Dala.Storage.move("/tmp/file.txt", Dala.Storage.dir(:documents) <> "/file.txt")
```

## Platform-specific storage

### iOS (Dala.Storage.Apple)

Additional location:

```elixir
# iCloud Drive (nil if unavailable)
path = Dala.Storage.Apple.dir(:icloud)
```

Save to photo library:

```elixir
# In your screen
def handle_event(:save_photo, _params, socket) do
  socket = Dala.Storage.Apple.save_to_photo_library(socket, "/tmp/photo.jpg")
  {:noreply, socket}
end

# Handle async result
def handle_info({:storage, :saved_to_library, path}, socket) do
  {:noreply, socket}
end

def handle_info({:storage, :error, :save_to_library, reason}, socket) do
  {:noreply, socket}
end
```

### Android (Dala.Storage.Android)

External storage directory:

```elixir
# Scoped external storage (no permission required)
path = Dala.Storage.Android.external_files_dir(:documents)
#=> "/storage/emulated/0/Android/data/com.example.app/files/Documents"
```

Save to MediaStore (appears in Gallery/Files app):

```elixir
# In your screen
def handle_event(:save_to_gallery, _params, socket) do
  socket = Dala.Storage.Android.save_to_media_store(socket, "/tmp/image.jpg", :image)
  {:noreply, socket}
end

# Handle async result
def handle_info({:storage, :saved_to_library, path}, socket) do
  {:noreply, socket}
end
```

## File picker

Open the system file picker for user-selected files:

```elixir
# In your screen
def handle_event(:pick_file, _params, socket) do
  socket = Dala.Storage.Files.pick(socket, types: ["image/*", "application/pdf"])
  {:noreply, socket}
end

# Handle result
def handle_info({:files, :picked, items}, socket) do
  # items => [%{path: "...", name: "photo.jpg", mime: "image/jpeg", size: 102400}, ...]
  {:noreply, socket}
end

def handle_info({:files, :cancelled}, socket) do
  {:noreply, socket}
end
```

## Error handling

All operations return `{:ok, value}` or `{:error, reason}`:

```elixir
case Dala.Storage.read("/tmp/config.json") do
  {:ok, content} ->
    Config.parse(content)

  {:error, :enoent} ->
    # File doesn't exist, use defaults
    Config.default()

  {:error, reason} ->
    Logger.error("Failed to read config: #{inspect(reason)}")
    Config.default()
end
```

## Complete example

```elixir
defmodule MyApp do
  alias Dala.Storage

  def save_note(title, body) do
    dir = Storage.dir(:documents)
    path = Path.join(dir, "#{title}.txt")

    with :ok <- Storage.ensure_dir(path),
         {:ok, _} <- Storage.write_text(path, body),
         {:ok, info} <- Storage.info(path) do
      {:ok, info}
    end
  end

  def load_notes do
    case Storage.list(:documents) do
      {:ok, paths} ->
        paths
        |> Enum.filter(&(Storage.extension(&1) == ".txt"))
        |> Enum.map(fn path ->
          {:ok, content} = Storage.read_text(path)
          %{name: Path.basename(path), content: content}
        end)

      {:error, _} ->
        []
    end
  end

  def export_note(title, dest) do
    src = Path.join(Storage.dir(:documents), "#{title}.txt")
    Storage.export(src, dest)
  end

  def delete_note(title) do
    path = Path.join(Storage.dir(:documents), "#{title}.txt")
    Storage.delete(path)
  end
end
```
