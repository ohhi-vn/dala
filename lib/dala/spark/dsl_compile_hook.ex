defmodule Dala.Spark.DslCompileHook do
  @moduledoc """
  Compile-time hook that verifies DSL definitions when screen modules are compiled.

  This module is used via `@before_compile` in `Dala.Spark.Dsl` and runs
  verification on the module's DSL state after all transformers have completed.
  Warnings are printed to the compiler output.
  """

  @doc """
  Called automatically by the `@before_compile` mechanism.
  """
  defmacro __before_compile__(env) do
    module = env.module

    # Only verify modules that use Dala.Spark.Dsl
    if Module.get_attribute(module, :__dala_dsl__) do
      verify_and_warn(module, env)
    end

    quote do
      # no runtime code injected
    end
  end

  defp verify_and_warn(module, env) do
    # Gather DSL info from module attributes
    entities = Module.get_attribute(module, :__dala_dsl_entities__) || []
    attributes = Module.get_attribute(module, :__dala_dsl_attributes__) || []
    handlers = gather_handlers(module, env)

    warnings =
      Dala.Spark.DslVerifier.verify_from_raw(module, entities, attributes, handlers)

    if warnings != [] do
      file = env.file
      line = 1

      Enum.each(warnings, fn w ->
        w_line = if w.line > 0, do: w.line, else: line

        Mix.shell().info(
          IO.ANSI.format([
            :yellow,
            "warning: ",
            :reset,
            w.message,
            "\n  ",
            :cyan,
            "#{file}:#{w_line}",
            :reset
          ])
        )

        # Also emit proper compiler warning
        IO.write(:standard_error, "warning: #{w.message}\n  #{file}:#{w_line}\n")
      end)
    end
  end

  defp gather_handlers(module, _env) do
    # Check if the module exports handle_event/3
    if function_exported?(module, :handle_event, 3) do
      # We can't easily extract the clause patterns at compile time,
      # so we rely on the runtime __spark_dsl__ info
      []
    else
      []
    end
  end
end
