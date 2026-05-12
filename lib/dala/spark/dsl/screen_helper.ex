defmodule Dala.Spark.Dsl.ScreenHelper do
  @moduledoc false

  # No macros needed. Spark's section builder generates `screen/1` and
  # `screen/2` (with do-block) automatically when `top_level?: true`
  # is set on the @screen section.
  #
  # Usage: `screen name: :counter do ... end`
  #
  # This module exists only for documentation.
end
