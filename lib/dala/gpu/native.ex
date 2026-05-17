defmodule Dala.Gpu.Native do
  @moduledoc false
  # NIF bindings for the dala_gpu Rust crate.
  # All functions return :nif_not_loaded until the Rust crate is compiled and linked.

  use Rustler,
    otp_app: :dala,
    crate: :dala_gpu

  # ── Surface lifecycle ─────────────────────────────────────────────────────

  @doc "Create a new GPU surface with the given width and height. Returns a reference."
  @spec surface_new(non_neg_integer(), non_neg_integer()) :: reference()
  def surface_new(_width, _height), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Destroy a GPU surface and free all associated GPU resources."
  @spec surface_destroy(reference()) :: :ok
  def surface_destroy(_ref), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Resize an existing GPU surface. May reallocate the GPU texture."
  @spec surface_resize(reference(), non_neg_integer(), non_neg_integer()) :: :ok
  def surface_resize(_ref, _width, _height), do: :erlang.nif_error(:nif_not_loaded)

  # ── Commands ──────────────────────────────────────────────────────────────

  @doc "Submit a binary-encoded command to the surface's command queue."
  @spec surface_command(reference(), binary()) :: :ok
  def surface_command(_ref, _cmd_binary), do: :erlang.nif_error(:nif_not_loaded)

  # ── Pixel access ──────────────────────────────────────────────────────────

  @doc "Get the current pixel data as an RGBA8888 binary."
  @spec surface_get_pixels(reference()) :: binary()
  def surface_get_pixels(_ref), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Set the pixel data from an RGBA8888 binary. Binary size must equal width * height * 4."
  @spec surface_set_pixels(reference(), binary()) :: :ok
  def surface_set_pixels(_ref, _rgba_data), do: :erlang.nif_error(:nif_not_loaded)

  # ── Info ──────────────────────────────────────────────────────────────────

  @doc "Get the width of the surface in pixels."
  @spec surface_width(reference()) :: non_neg_integer()
  def surface_width(_ref), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Get the height of the surface in pixels."
  @spec surface_height(reference()) :: non_neg_integer()
  def surface_height(_ref), do: :erlang.nif_error(:nif_not_loaded)

  # ── Compute / Shader ──────────────────────────────────────────────────────

  @doc "Dispatch a GPU compute shader on the surface."
  @spec surface_dispatch_compute(reference(), binary(), binary(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: :ok
  def surface_dispatch_compute(_ref, _shader, _params, _wg_x, _wg_y, _wg_z), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Read pixel data back from the GPU."
  @spec surface_read_pixels(reference(), non_neg_integer(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: binary()
  def surface_read_pixels(_ref, _x, _y, _w, _h), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Load or hot-reload a shader."
  @spec surface_load_shader(reference(), binary(), binary()) :: :ok
  def surface_load_shader(_ref, _name, _source), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Set a uniform value on the current shader pipeline."
  @spec surface_set_uniform(reference(), binary(), binary()) :: :ok
  def surface_set_uniform(_ref, _name, _data), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Check if the GPU backend supports compute shaders."
  @spec surface_supports_compute(reference()) :: boolean()
  def surface_supports_compute(_ref), do: :erlang.nif_error(:nif_not_loaded)
end
