defmodule Dala.Gpu.Compute.Kernel do
  @moduledoc """
  Kernel execution and registry for GPU compute.

  Kernels are identified by atoms and executed on the GPU via CubeCL.
  This module provides a registry for custom kernels and helpers for
  common operations.

  ## Built-in Kernels

  | Kernel              | Description                          |
  |---------------------|--------------------------------------|
  | `:elementwise_add`  | Elementwise addition (2 inputs)       |
  | `:elementwise_mul`  | Elementwise multiplication (2 inputs) |
  | `:scalar_mul`       | Scalar multiplication (1 input + scalar param) |
  | `:relu`             | ReLU activation (1 input)            |
  | `:sigmoid`          | Sigmoid activation (1 input)         |
  | `:matmul`           | Matrix multiplication (2 inputs)     |
  | `:blur`             | Gaussian blur (1 input + radius/sigma params) |
  | `:sharpen`          | Sharpen filter (1 input)             |
  | `:grayscale`        | RGB to grayscale (1 input)           |
  | `:lut`              | Color LUT transform (1 input + lut param) |

  ## Custom Kernels

  Register custom kernels at compile time:

      defmodule MyKernels do
        use Dala.Gpu.Compute.Kernel

        kernel :custom_blur do
          \"\"\"
          // CubeCL kernel code
          fn input: Tensor<f32>, output: Tensor<f32>, params: Map {
            // ...
          }
          \"\"\"
        end
      end

  ## Execution Model

  Kernels run on the dirty CPU scheduler to avoid blocking the BEAM.
  On iOS, kernels compile to Metal shaders. On Android, to OpenGL ES
  compute shaders. On desktop (dev), a CPU fallback is used.

  ## EXCubeCL 0.4+ Compatibility

  Dala uses atom kernel names (`:elementwise_add`) internally and
  translates to EXCubeCL string names (`"elementwise_add"`) at the
  boundary. The `run/4` and `async_run/4` functions accept both
  atoms and strings.
  """

  alias Dala.Gpu.Compute.Buffer

  @type kernel_spec :: %{
          name: atom(),
          source: String.t(),
          inputs: non_neg_integer(),
          params: [atom()]
        }

  @doc "Run a named kernel synchronously."
  @spec run(atom(), [Buffer.t()], Buffer.t(), map()) :: :ok | {:error, term()}
  def run(kernel, inputs, output, params \\ %{}) do
    input_refs = Enum.map(inputs, & &1.ref)
    kernel_string = kernel_to_string(kernel)

    case ExCubecl.run_kernel(kernel_string, input_refs, output.ref, params) do
      {:ok, _cmd_id} -> :ok
      {:error, _reason} = err -> err
    end
  end

  @doc "Run a kernel asynchronously. Returns a command ID."
  @spec async_run(atom(), [Buffer.t()], Buffer.t(), map()) :: non_neg_integer()
  def async_run(kernel, inputs, output, params \\ %{}) do
    input_refs = Enum.map(inputs, & &1.ref)
    kernel_string = kernel_to_string(kernel)

    {:ok, cmd_id} =
      ExCubecl.submit(
        "run_kernel #{kernel_string} #{inspect(input_refs)} #{inspect(output.ref)} #{inspect(params)}"
      )

    cmd_id
  end

  @doc "Register a custom kernel at runtime."
  @spec register(atom(), String.t(), keyword()) :: :ok | {:error, term()}
  def register(name, source, opts \\ []) do
    inputs = Keyword.get(opts, :inputs, 1)
    params = Keyword.get(opts, :params, [])

    # Store in the kernel registry (ETS table)
    :ets.insert(:dala_gpu_kernels, {name, source, inputs, params})
    :ok
  end

  @doc "Look up a registered kernel."
  @spec lookup(atom()) :: {:ok, kernel_spec()} | :error
  def lookup(name) do
    case :ets.lookup(:dala_gpu_kernels, name) do
      [{^name, source, inputs, params}] ->
        {:ok, %{name: name, source: source, inputs: inputs, params: params}}

      [] ->
        :error
    end
  end

  @doc "List all registered kernel names."
  @spec list() :: [atom()]
  def list do
    :ets.tab2list(:dala_gpu_kernels)
    |> Enum.map(fn {name, _, _, _} -> name end)
  end

  @doc "Initialize the kernel registry ETS table."
  @spec init_registry() :: :ok
  def init_registry do
    case :ets.whereis(:dala_gpu_kernels) do
      :undefined ->
        :ets.new(:dala_gpu_kernels, [:set, :public, :named_table, read_concurrency: true])

      _ ->
        :ok
    end

    :ok
  end

  @doc "Clear all registered kernels."
  @spec clear_registry() :: :ok
  def clear_registry do
    case :ets.whereis(:dala_gpu_kernels) do
      :undefined ->
        :ok

      _ ->
        :ets.delete_all_objects(:dala_gpu_kernels)
        :ok
    end
  end

  # Private: convert atom or string kernel name to EXCubeCL string.
  defp kernel_to_string(kernel) when is_atom(kernel), do: Atom.to_string(kernel)
  defp kernel_to_string(kernel) when is_binary(kernel), do: kernel
end
