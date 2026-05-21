defmodule Dala.Gpu.Compute.Buffer do
  @moduledoc """
  Typed wrapper around EXCubeCL GPU buffers.

  Provides a struct-based API so buffers can be passed around safely
  and matched on in function heads.

  ## Lifecycle

  1. Create via `new/3`, `zeros/2`, or `from_binary/3`
  2. Use in `Dala.Gpu.Compute.run_kernel/4` or `Dala.Gpu.Compute.submit/1`
  3. Read results via `Dala.Gpu.Compute.read/1`
  4. Free via `Dala.Gpu.Compute.free/1`

  Buffers are automatically freed when the owning process exits
  (via monitor-based cleanup), but explicit `free/1` is recommended
  for long-lived processes.
  """

  @type t :: %__MODULE__{
          ref: reference(),
          shape: tuple(),
          dtype: atom(),
          size_bytes: non_neg_integer()
        }

  defstruct [:ref, :shape, :dtype, :size_bytes]

  @doc "Create a new GPU buffer from a list of values."
  @spec new(list(), tuple(), atom()) :: t()
  def new(data, shape, dtype \\ :f32) do
    ref = ExCubecl.buffer(data, shape, dtype)
    size_bytes = ExCubecl.size(ref)
    %__MODULE__{ref: ref, shape: shape, dtype: dtype, size_bytes: size_bytes}
  end

  @doc "Create a zero-initialized GPU buffer."
  @spec zeros(tuple(), atom()) :: t()
  def zeros(shape, dtype \\ :f32) do
    {total_size, _} =
      Enum.reduce(shape, {1, shape}, fn dim, {acc, _} -> {acc * dim, nil} end)

    data = List.duplicate(0.0, total_size)
    new(data, shape, dtype)
  end

  @doc "Create a GPU buffer from a raw binary."
  @spec from_binary(binary(), tuple(), atom()) :: t()
  def from_binary(data, shape, dtype \\ :u8) do
    # EXCubeCL expects a list, so we convert binary to list
    list_data = :erlang.binary_to_list(data)
    new(list_data, shape, dtype)
  end

  @doc "Return the total number of elements in the buffer."
  @spec num_elements(t()) :: non_neg_integer()
  def num_elements(%__MODULE__{shape: shape}) do
    Enum.reduce(Tuple.to_list(shape), 1, &(&1 * &2))
  end

  @doc "Return true if the buffer is valid (has a non-nil ref)."
  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{ref: ref}), do: not is_nil(ref)
end
