defmodule Dala.Storage.StorageTest do
  use ExUnit.Case, async: true

  alias Dala.Storage.Storage

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "dala_storage_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)
    on_exit(fn -> File.rm_rf!(tmp_dir) end)
    %{tmp_dir: tmp_dir}
  end

  describe "create/1" do
    test "creates an empty file", %{tmp_dir: dir} do
      path = Path.join(dir, "empty.txt")
      assert {:ok, ^path} = Storage.create(path)
      assert File.exists?(path)
      assert File.read!(path) == ""
    end

    test "creates parent directories as needed", %{tmp_dir: dir} do
      path = Path.join(dir, "nested/dir/file.txt")
      assert {:ok, ^path} = Storage.create(path)
      assert File.exists?(path)
    end

    test "succeeds when file already exists", %{tmp_dir: dir} do
      path = Path.join(dir, "existing.txt")
      File.write!(path, "old content")
      assert {:ok, ^path} = Storage.create(path)
      # File.touch does not erase existing content
      assert File.read!(path) == "old content"
    end
  end

  describe "create/2" do
    test "creates file with content", %{tmp_dir: dir} do
      path = Path.join(dir, "hello.txt")
      assert {:ok, ^path} = Storage.create(path, "Hello, World!")
      assert File.read!(path) == "Hello, World!"
    end

    test "creates parent directories as needed", %{tmp_dir: dir} do
      path = Path.join(dir, "a/b/c.bin")
      assert {:ok, ^path} = Storage.create(path, <<1, 2, 3>>)
      assert File.read!(path) == <<1, 2, 3>>
    end

    test "overwrites existing file content", %{tmp_dir: dir} do
      path = Path.join(dir, "overwrite.txt")
      File.write!(path, "old")
      assert {:ok, ^path} = Storage.create(path, "new")
      assert File.read!(path) == "new"
    end
  end

  describe "update/2" do
    test "updates existing file content", %{tmp_dir: dir} do
      path = Path.join(dir, "update.txt")
      File.write!(path, "original")
      assert {:ok, ^path} = Storage.update(path, "updated")
      assert File.read!(path) == "updated"
    end

    test "returns {:error, :enoent} for missing file", %{tmp_dir: dir} do
      path = Path.join(dir, "nonexistent.txt")
      assert {:error, :enoent} = Storage.update(path, "content")
    end
  end

  describe "delete/1" do
    test "deletes a file", %{tmp_dir: dir} do
      path = Path.join(dir, "file.txt")
      File.write!(path, "content")
      assert :ok = Storage.delete(path)
      refute File.exists?(path)
    end

    test "returns error for nonexistent path", %{tmp_dir: dir} do
      assert {:error, _} = Storage.delete(Path.join(dir, "nonexistent.txt"))
    end
  end

  describe "delete/2 with force option" do
    test "force: true deletes non-empty directory", %{tmp_dir: dir} do
      dir_path = Path.join(dir, "nested/dir")
      File.mkdir_p!(dir_path)
      File.write!(Path.join(dir_path, "file.txt"), "content")
      assert :ok = Storage.delete(Path.join(dir, "nested"), force: true)
      refute File.exists?(Path.join(dir, "nested"))
    end

    test "force: true deletes empty directory", %{tmp_dir: dir} do
      dir_path = Path.join(dir, "empty_dir")
      File.mkdir_p!(dir_path)
      assert :ok = Storage.delete(dir_path, force: true)
      refute File.exists?(dir_path)
    end
  end

  describe "move/2" do
    test "moves file to new path", %{tmp_dir: dir} do
      src = Path.join(dir, "src.txt")
      dest = Path.join(dir, "dest.txt")
      File.write!(src, "content")
      assert {:ok, ^dest} = Storage.move(src, dest)
      assert File.read!(dest) == "content"
      refute File.exists?(src)
    end

    test "creates parent directories of dest", %{tmp_dir: dir} do
      src = Path.join(dir, "src.txt")
      dest = Path.join([dir, "new_dir", "dest.txt"])
      File.write!(src, "content")
      assert {:ok, ^dest} = Storage.move(src, dest)
      assert File.read!(dest) == "content"
    end

    test "returns error for missing source", %{tmp_dir: dir} do
      assert {:error, _} = Storage.move(Path.join(dir, "missing.txt"), Path.join(dir, "dest.txt"))
    end
  end

  describe "export/2" do
    test "copies file to destination", %{tmp_dir: dir} do
      src = Path.join(dir, "original.txt")
      dest = Path.join(dir, "copy.txt")
      File.write!(src, "data")
      assert {:ok, ^dest} = Storage.export(src, dest)
      assert File.read!(dest) == "data"
      assert File.exists?(src)
    end

    test "creates parent directories of dest", %{tmp_dir: dir} do
      src = Path.join(dir, "file.txt")
      dest = Path.join(dir, "backup/copy.txt")
      File.write!(src, "data")
      assert {:ok, ^dest} = Storage.export(src, dest)
      assert File.read!(dest) == "data"
    end

    test "returns error for missing source", %{tmp_dir: dir} do
      assert {:error, _} = Storage.export(Path.join(dir, "missing.txt"), Path.join(dir, "dest.txt"))
    end
  end

  describe "info/1" do
    test "returns file metadata", %{tmp_dir: dir} do
      path = Path.join(dir, "info_test.txt")
      File.write!(path, "hello")
      assert {:ok, info} = Storage.info(path)
      assert info.name == "info_test.txt"
      assert info.path == path
      assert info.size == 5
      assert info.type == :regular
      assert info.extension == ".txt"
      assert %DateTime{} = info.modified_at
    end

    test "returns error for missing file", %{tmp_dir: dir} do
      assert {:error, _} = Storage.info(Path.join(dir, "nonexistent.txt"))
    end
  end

  describe "exists?/1" do
    test "returns true for existing file", %{tmp_dir: dir} do
      path = Path.join(dir, "present.txt")
      File.write!(path, "content")
      assert Storage.exists?(path)
    end

    test "returns false for missing file", %{tmp_dir: dir} do
      refute Storage.exists?(Path.join(dir, "absent.txt"))
    end

    test "returns true for existing directory", %{tmp_dir: dir} do
      subdir = Path.join(dir, "subdir")
      File.mkdir_p!(subdir)
      assert Storage.exists?(subdir)
    end
  end

  describe "ensure_dir/1" do
    test "creates parent directory", %{tmp_dir: dir} do
      path = Path.join(dir, "new_dir/file.txt")
      assert :ok = Storage.ensure_dir(path)
      assert File.dir?(Path.join(dir, "new_dir"))
    end

    test "succeeds when directory already exists", %{tmp_dir: dir} do
      assert :ok = Storage.ensure_dir(Path.join(dir, "file.txt"))
    end
  end

  describe "size/1" do
    test "returns file size in bytes", %{tmp_dir: dir} do
      path = Path.join(dir, "sized.txt")
      File.write!(path, "12345")
      assert {:ok, 5} = Storage.size(path)
    end

    test "returns 0 for empty file", %{tmp_dir: dir} do
      path = Path.join(dir, "empty.txt")
      File.write!(path, "")
      assert {:ok, 0} = Storage.size(path)
    end

    test "returns error for missing file", %{tmp_dir: dir} do
      assert {:error, _} = Storage.size(Path.join(dir, "nonexistent.txt"))
    end
  end

  describe "append/2" do
    test "appends to existing file", %{tmp_dir: dir} do
      path = Path.join(dir, "log.txt")
      File.write!(path, "first")
      assert {:ok, ^path} = Storage.append(path, "second")
      assert File.read!(path) == "firstsecond"
    end

    test "creates file if missing", %{tmp_dir: dir} do
      path = Path.join(dir, "new_log.txt")
      assert {:ok, ^path} = Storage.append(path, "entry")
      assert File.read!(path) == "entry"
    end

    test "creates parent directories if needed", %{tmp_dir: dir} do
      path = Path.join(dir, "logs/app.log")
      assert {:ok, ^path} = Storage.append(path, "start")
      assert File.read!(path) == "start"
    end
  end

  describe "read_text/1" do
    test "reads file content", %{tmp_dir: dir} do
      path = Path.join(dir, "text.txt")
      File.write!(path, "Hello, World!")
      assert {:ok, "Hello, World!"} = Storage.read_text(path)
    end

    test "returns error for missing file", %{tmp_dir: dir} do
      assert {:error, _} = Storage.read_text(Path.join(dir, "nonexistent.txt"))
    end
  end

  describe "write_text/2" do
    test "writes text content", %{tmp_dir: dir} do
      path = Path.join(dir, "output.txt")
      assert {:ok, ^path} = Storage.write_text(path, "Hello!")
      assert File.read!(path) == "Hello!"
    end

    test "creates parent directories", %{tmp_dir: dir} do
      path = Path.join(dir, "nested/output.txt")
      assert {:ok, ^path} = Storage.write_text(path, "content")
      assert File.read!(path) == "content"
    end

    test "overwrites existing file", %{tmp_dir: dir} do
      path = Path.join(dir, "overwrite.txt")
      File.write!(path, "old")
      assert {:ok, ^path} = Storage.write_text(path, "new")
      assert File.read!(path) == "new"
    end
  end

  describe "extension/1" do
    test "returns extension with leading dot" do
      assert Storage.extension("file.txt") == ".txt"
      assert Storage.extension("archive.tar.gz") == ".gz"
    end

    test "returns empty string for no extension" do
      assert Storage.extension("Makefile") == ""
    end

    test "works with paths" do
      assert Storage.extension("/tmp/data.json") == ".json"
    end
  end
end
