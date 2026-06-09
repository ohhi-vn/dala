defmodule DebugEntityTest do
  use ExUnit.Case

  test "check entity macro" do
    Code.ensure_loaded(Dala.Spark.Dsl.Screen.Column)
    funs = Dala.Spark.Dsl.Screen.Column.module_info(:functions)
    IO.inspect(Enum.map(funs, fn {f, _} -> f end), label: "functions")

    # Try calling __build__
    result =
      Dala.Spark.Dsl.Screen.Column.__build__(
        TestModule,
        [padding: :space_md, gap: :space_sm],
        [],
        nil,
        nil
      )

    IO.inspect(result, label: "build result")
  end
end
