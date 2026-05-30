defmodule Dala.Spark.DslDebugTest do
  use ExUnit.Case, async: false

  test "check extensions attribute with dala wrapper" do
    defmodule TestCheckExtensions do
      use Dala.Screen

      IO.puts("=== After use Dala.Screen ===")
      IO.puts("extensions: #{inspect(@extensions)}")
      IO.puts("dala: #{inspect(@dala)}")
      IO.puts("spark_extension_kinds: #{inspect(@spark_extension_kinds)}")

      dala do
        IO.puts("=== Inside dala block ===")
        IO.puts("extensions: #{inspect(@extensions)}")

        screen name: :test do
          IO.puts("=== Inside screen block ===")
          IO.puts("extensions: #{inspect(@extensions)}")
          text("Hello")
        end
      end
    end

    assert Code.ensure_loaded?(TestCheckExtensions)
  end

  test "check extensions attribute without dala wrapper" do
    defmodule TestCheckExtensions2 do
      use Dala.Screen

      IO.puts("=== After use Dala.Screen (no dala) ===")
      IO.puts("extensions: #{inspect(@extensions)}")
      IO.puts("dala: #{inspect(@dala)}")
      IO.puts("spark_extension_kinds: #{inspect(@spark_extension_kinds)}")

      screen name: :test do
        IO.puts("=== Inside screen block (no dala) ===")
        IO.puts("extensions: #{inspect(@extensions)}")
        text("Hello")
      end
    end

    assert Code.ensure_loaded?(TestCheckExtensions2)
  end
end
