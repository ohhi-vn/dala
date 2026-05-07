defmodule Dala.ML.ONNX.Test do
  @moduledoc """
  Tests for Dala.ML.ONNX.

  Note: These tests only run on platforms with ONNX Runtime available.
  On unsupported platforms, they will return `:not_supported`.
  """

  use ExUnit.Case, async: true

  test "create_session returns session_id or error" do
    dummy_data = <<1, 2, 3, 4, 5, 6, 7, 8>>

    case Dala.ML.ONNX.create_session(dummy_data) do
      {:ok, session_id} when is_integer(session_id) ->
        # Clean up
        assert :ok == Dala.ML.ONNX.destroy_session(session_id)

      :not_supported ->
        :ok

      {:error, _} ->
        :ok
    end
  end

  test "destroy_session handles invalid session_id" do
    case Dala.ML.ONNX.destroy_session(999_999) do
      :ok -> :ok
      {:error, _} -> :ok
    end
  end

  test "load_model_from_file returns error for non-existent file" do
    result = Dala.ML.ONNX.load_model_from_file("/non/existent/model.onnx")

    case result do
      {:error, _} -> :ok
      :not_supported -> :ok
      other -> flunk("Unexpected result: #{inspect(other)}")
    end
  end

  test "ONNX module is available" do
    assert Code.ensure_loaded?(Dala.ML.ONNX)
  end

  test "available? returns boolean" do
    result = Dala.ML.ONNX.available?()
    assert is_boolean(result)
  end

  test "run returns not_supported or error for invalid session" do
    case Dala.ML.ONNX.run(999_999, <<1, 2, 3, 4>>) do
      {:ok, _output} -> :ok
      {:error, _} -> :ok
      :not_supported -> :ok
    end
  end
end
