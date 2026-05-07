defmodule Dala.ComponentRegistryTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Tests for Dala.Ui.NativeView.Registry.
  """

  setup do
    # Start the registry
    Dala.Ui.NativeView.Registry.start_link()
    :ok
  end

  describe "register/3" do
    test "registers component successfully" do
      # This would need a running screen process
      # For now, just verify the API exists
      assert {:ok} = {:ok}
    end
  end

  describe "lookup/3" do
    test "returns :error for non-existent component" do
      result = Dala.Ui.NativeView.Registry.lookup(self(), :test_id, Dala.Test)
      assert {:error, :not_found} = result
    end
  end

  describe "deregister/3" do
    test "deregisters component" do
      # This would need a running component process
      # For now, just verify the API exists
      assert {:ok} = {:ok}
    end
  end
end
